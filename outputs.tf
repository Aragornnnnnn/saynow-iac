output "backend_instance_id" {
  description = "EC2 instance id for the Saynow backend."
  value       = aws_instance.backend.id
}

output "backend_public_ip" {
  description = "Elastic IPv4 address for the Saynow backend EC2 instance."
  value       = aws_eip.backend.public_ip
}

output "backend_public_dns" {
  description = "Public DNS name for the Saynow backend Elastic IP."
  value       = aws_eip.backend.public_dns
}

output "backend_app_url" {
  description = "Direct MVP URL for the Spring Boot backend."
  value       = "http://${aws_eip.backend.public_ip}:${var.app_port}"
}

output "backend_ssh_command" {
  description = "SSH command for EC2 access when the caller is allowed by ssh_allowed_cidr_blocks."
  value       = "ssh -i ~/.ssh/saynow-prod-deploy ec2-user@${aws_eip.backend.public_ip}"
}

output "backend_service_name" {
  description = "systemd service name used for backend deployments."
  value       = local.service_name
}

output "backend_eip_allocation_id" {
  description = "Elastic IP allocation id for the Saynow backend."
  value       = aws_eip.backend.allocation_id
}

output "backend_parameter_store_path" {
  description = "SSM Parameter Store path used for production environment variables."
  value       = var.parameter_store_path
}
