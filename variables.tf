variable "aws_region" {
  description = "AWS region for the Saynow MVP infrastructure."
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Short project name used in AWS resource names and tags."
  type        = string
  default     = "saynow"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}

variable "instance_type" {
  description = "EC2 instance type for the backend server."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = var.instance_type == "t3.micro"
    error_message = "MVP production EC2 must use the free-tier target instance type t3.micro."
  }
}

variable "ssh_public_key" {
  description = "Public key registered as an AWS key pair for EC2 SSH deployment access."
  type        = string
  sensitive   = true
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the EC2 instance."
  type        = list(string)
  default     = []
}

variable "app_port" {
  description = "Spring Boot server port exposed by the EC2 security group and systemd service."
  type        = number
  default     = 8080
}

variable "app_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the Spring Boot application port."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 8
}
