provider "ibm" {
  region = var.region
}

data "ibm_resource_group" "rg" {
  count = var.resource_group == "Default" ? 0 : 1
  name  = var.resource_group
}

data "ibm_is_image" "image" {
  name = var.vpc_vsi_image_name
}

data "cloudinit_config" "config" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "config.yaml"
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/scripts/cloud-config.tftpl", {})
  }

  part {
    filename     = "initial-setup.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/scripts/initial-setup.tftpl", {
      os_name            = "${data.ibm_is_image.image.operating_system[0].name}",
      jupyter_lab_image  = var.jupyter_lab_image,
      gpu_count          = var.gpu_count,
      cpu_reservation    = var.cpu_reservation,
      memory_reservation = var.memory_reservation,
      cpu_limit          = var.cpu_limit,
      memory_limit       = var.memory_limit,
      tcp_port_min       = tostring(var.tcp_port_min),
      tcp_port_max       = tostring(var.tcp_port_max)
    })
  }
}

data "ibm_is_ssh_key" "keys" {
  for_each = toset([for key in var.keys : tostring(key)])
  name     = each.value
}

locals {
  keys = [
    for key in data.ibm_is_ssh_key.keys : key.id
  ]
}

resource "ibm_is_vpc" "vpc" {
  name                        = var.vpc
  resource_group              = var.resource_group == "Default" ? null : data.ibm_resource_group.rg[0].id
  default_security_group_name = "${var.vpc}-default-sg"
  default_routing_table_name  = "${var.vpc}-default-rt"
  default_network_acl_name    = "${var.vpc}-default-na"
}

resource "ibm_is_subnet" "subnet" {
  name                     = "${var.vpc}-${var.zone}-sn"
  resource_group           = var.resource_group == "Default" ? null : data.ibm_resource_group.rg[0].id
  vpc                      = ibm_is_vpc.vpc.id
  zone                     = var.zone
  total_ipv4_address_count = 64
}

resource "ibm_is_security_group" "sg" {
  name           = "${var.vpc}-sg"
  resource_group = var.resource_group == "Default" ? null : data.ibm_resource_group.rg[0].id
  vpc            = ibm_is_vpc.vpc.id
}

resource "ibm_is_security_group_rule" "inbound-rule-icmp" {
  group     = ibm_is_security_group.sg.id
  direction = "inbound"
  icmp {
    type = 8
    code = 0
  }
}

resource "ibm_is_security_group_rule" "inbound-rule-ssh" {
  group     = ibm_is_security_group.sg.id
  direction = "inbound"
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "inbound-rule-tcp-range" {
  group     = ibm_is_security_group.sg.id
  direction = "inbound"
  tcp {
    port_min = var.tcp_port_min
    port_max = var.tcp_port_max
  }
}

resource "ibm_is_security_group_rule" "inbound-rule-jupyter" {
  group     = ibm_is_security_group.sg.id
  direction = "inbound"
  tcp {
    port_min = 8888
    port_max = 8888
  }
}

resource "ibm_is_security_group_rule" "outbound-rule-dns-udp" {
  group     = ibm_is_security_group.sg.id
  direction = "outbound"
  udp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "outbound-rule-dns-tcp" {
  group     = ibm_is_security_group.sg.id
  direction = "outbound"
  tcp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "outbound-rule-http" {
  group     = ibm_is_security_group.sg.id
  direction = "outbound"
  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_security_group_rule" "outbound-rule-https" {
  group     = ibm_is_security_group.sg.id
  direction = "outbound"
  tcp {
    port_min = 443
    port_max = 443
  }
}

resource "ibm_is_security_group_rule" "outbound-rule-all" {
  group     = ibm_is_security_group.sg.id
  direction = "outbound"
}

resource "ibm_is_instance" "vsi" {
  name           = "${var.vpc}-vsi"
  resource_group = var.resource_group == "Default" ? null : data.ibm_resource_group.rg[0].id
  vpc            = ibm_is_vpc.vpc.id
  zone           = var.zone
  image          = data.ibm_is_image.image.id
  profile        = var.vpc_vsi_profile_name
  keys           = local.keys[*]
  user_data      = data.cloudinit_config.config.rendered

  boot_volume {
    name = "${var.vpc}-vsi-boot-volume"
    size = 250
  }

  primary_network_interface {
    name   = "${var.vpc}-vsi-primary-interface"
    subnet = ibm_is_subnet.subnet.id
    security_groups = [
      ibm_is_security_group.sg.id
    ]
  }

  lifecycle {
    precondition {
      condition     = var.tcp_port_max >= var.tcp_port_min
      error_message = "The value of tcp_port_max must be equal to or greater than that of tcp_port_min."
    }
  }
}

resource "ibm_is_floating_ip" "vsi-fip" {
  name           = "${var.vpc}-vsi-fip"
  resource_group = var.resource_group == "Default" ? null : data.ibm_resource_group.rg[0].id
  target         = ibm_is_instance.vsi.primary_network_interface[0].id
  depends_on     = [ibm_is_instance.vsi]
}

resource "ibm_is_instance_volume_attachment" "vsi-data-volume-attachment" {
  instance                           = ibm_is_instance.vsi.id
  name                               = "${var.vpc}-vsi-data-volume-attachment"
  profile                            = "10iops-tier"
  capacity                           = var.vpc_vsi_data_volume_size
  delete_volume_on_attachment_delete = true
  delete_volume_on_instance_delete   = true
  volume_name                        = "${var.vpc}-vsi-data-volume"
}

