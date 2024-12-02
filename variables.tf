variable "resource_group" {
  description = "The name of the Resource Group"
  type        = string
  default     = "Default"
}

variable "region" {
  description = "The name of the region"
  type        = string
  default     = "ca-tor"
}

variable "zone" {
  description = "The name of the avalability zone"
  type        = string
  default     = "ca-tor-1"
}

variable "vpc" {
  description = "The name of the VPC"
  type        = string
}

variable "classic_access" {
  description = "Enable VPC access to classic infrastructure"
  type        = bool
  default     = false
}

variable "keys" {
  description = "The list of VPC SSH Key names"
  type        = list(string)
}

variable "tags" {
  description = "The tags for the resources"
  type        = list(string)
  default     = []
}

variable "vpc_vsi_image_name" {
  description = "VPC VSI image name"
  type        = string
  default     = "ibm-ubuntu-22-04-3-minimal-amd64-2"
}

variable "vpc_vsi_profile_name" {
  description = "VPC VSI profile name"
  type        = string
  default     = "gx3-16x80x1l4"
}

variable "jupyter_lab_image" {
  description = "Jupyter Lab container image"
  type        = string
  default     = "quay.io/jupyter/pytorch-notebook:cuda12-latest"
}

variable "gpu_count" {
  description = "GPU counnt for Jupyter Lab container"
  type        = string
  default     = "all"
}

variable "cpu_reservation" {
  description = "CPU reservation for Jupyter Lab container"
  type        = string
  default     = "0"
}

variable "memory_reservation" {
  description = "Memory reservation for Jupyter Lab container"
  type        = string
  default     = "0G"

  validation {
    condition = (
      var.memory_reservation == null ||
      can(regex("(^\\d+(M|G)$)", var.memory_reservation))
    )
    error_message = "Specify the memory size in number of megabytes (M) or gigabytes (G)."
  }
}

variable "cpu_limit" {
  description = "CPU limit for Jupyter Lab container"
  type        = string
  default     = "0"
}

variable "memory_limit" {
  description = "Memory limit for Jupyter Lab container"
  type        = string
  default     = "0G"

  validation {
    condition = (
      var.memory_limit == null ||
      can(regex("(^\\d+(M|G)$)", var.memory_limit))
    )
    error_message = "Specify the memory size in number of megabytes (M) or gigabytes (G)."
  }
}

variable "vpc_vsi_data_volume_size" {
  description = "The size of the data volume in GB for the VPC VSI"
  type        = string
  default     = "1000"
}

variable "tcp_port_min" {
  description = "The minimum bound of exposed TCP port range, inclusive."
  type        = number
  default     = 8502

  validation {
    condition = (
      var.tcp_port_min >= 1 && var.tcp_port_min <= 65535
    )
    error_message = "It must be a number between 1 and 65535, inclusive."
  }
}

variable "tcp_port_max" {
  description = "The maximum bound of exposed TCP port range, inclusive."
  type        = number
  default     = 8502

  validation {
    condition = (
      var.tcp_port_max >= 1 && var.tcp_port_max <= 65535
    )
    error_message = "It must be a number between 1 and 65535, inclusive."
  }
}

