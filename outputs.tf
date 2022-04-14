output "instance_client" {
  description = "Client"
  value       = "${module.client.aws_instance.id}\nPrivate IP: ${module.client.aws_instance.private_ip}\nPublic IP: ${module.client.aws_instance.public_ip}"
}

output "instance_web" {
  description = "Web Server"
  value       = "${module.web_server.aws_instance.id}\nPrivate IP: ${module.web_server.aws_instance.private_ip}\nPublic IP: ${module.web_server.aws_instance.public_ip}"
}

output "privatelink" {
  description = "PrivateLink / VPC Endpoint"
  value       = "${aws_vpc_endpoint.web_ep.id}\nDNS name: ${aws_vpc_endpoint.web_ep.dns_entry[0].dns_name}\nPrivate IP: ${data.aws_network_interface.web_ep_eni.private_ip}"
}

output "nlb" {
  description = "NLB"
  value       = "${module.nlb.lb_id}\nPrivate IP: ${data.aws_network_interface.nlb_eni.private_ip}"
}