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

output "backend_security_group_id" {
  description = "Security group id for the Saynow backend EC2 instance."
  value       = aws_security_group.backend.id
}

output "backend_github_actions_deploy_role_arn" {
  description = "GitHub Actions OIDC role ARN for backend deployment."
  value       = aws_iam_role.github_actions_backend_deploy.arn
}

output "ai_instance_id" {
  description = "EC2 instance id for the Saynow AI backend."
  value       = aws_instance.ai_backend.id
}

output "ai_public_ip" {
  description = "Elastic IPv4 address for the Saynow AI backend EC2 instance."
  value       = aws_eip.ai_backend.public_ip
}

output "ai_app_url" {
  description = "Direct URL for the FastAPI AI backend."
  value       = "http://${aws_eip.ai_backend.public_ip}:${var.app_port}"
}

output "ai_ssh_command" {
  description = "SSH command for AI EC2 access when the caller is allowed by ssh_allowed_cidr_blocks."
  value       = "ssh -i ~/.ssh/saynow-prod-deploy ec2-user@${aws_eip.ai_backend.public_ip}"
}

output "ai_service_name" {
  description = "systemd service name used for AI backend deployments."
  value       = local.ai_service_name
}

output "ai_security_group_id" {
  description = "Security group id for the Saynow AI backend EC2 instance."
  value       = aws_security_group.ai_backend.id
}

output "ai_github_actions_deploy_role_arn" {
  description = "GitHub Actions OIDC role ARN for AI backend deployment."
  value       = aws_iam_role.github_actions_ai_deploy.arn
}
