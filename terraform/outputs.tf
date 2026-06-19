output "server_ip" {
  description = "Server IPv4 address"
  value       = hcloud_server.headscale.ipv4_address
}

output "server_ipv6" {
  description = "Server IPv6 address"
  value       = hcloud_server.headscale.ipv6_address
}