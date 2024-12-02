output "public_ip" {
  description = "Public IP"
  value       = ibm_is_floating_ip.vsi-fip.address
}

output "jupyter_server_url" {
  description = "URL to the deployed Jupyter server"
  value       = "https://${ibm_is_floating_ip.vsi-fip.address}:8888/"
  depends_on  = [ibm_is_floating_ip.vsi-fip]
}

