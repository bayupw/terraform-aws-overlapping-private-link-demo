output "client_ssm_session" {
  description = "Client Instance SSM command"
  value       = "aws ssm start-session --region ${data.aws_region.current.name} --target ${module.client.aws_instance.id}"
}

output "client_private_ip" {
  description = "Client Private IP"
  value       = module.client.aws_instance.private_ip
}

output "web_ssm_session" {
  description = "Client Instance SSM command"
  value       = "aws ssm start-session --region ${data.aws_region.current.name} --target ${module.web_server.aws_instance.id}"
}

output "web_private_ip" {
  description = "Web Server Private IP"
  value       = module.web_server.aws_instance.private_ip
}

output "privatelink_dns_name" {
  description = "PrivateLink DNS Name"
  value       = aws_vpc_endpoint.web_ep.dns_entry[0].dns_name
}

output "privatelink_private_ip" {
  description = "PrivateLink Private IP"
  value       = data.aws_network_interface.web_ep_eni.private_ip
}

output "nlb_private_ip" {
  description = "NLB Private IP"
  value       = data.aws_network_interface.nlb_eni.private_ip
}