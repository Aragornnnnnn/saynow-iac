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

variable "backend_domain_name" {
  description = "Public domain name for the Saynow backend HTTPS endpoint."
  type        = string
  default     = "saynow.p-e.kr"

  validation {
    condition     = trimspace(var.backend_domain_name) != ""
    error_message = "backend_domain_name must not be empty."
  }
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
  description = "Application port used by the backend and AI services. Backend public traffic is handled by Caddy."
  type        = number
  default     = 8080
}

variable "app_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access services that still expose app_port directly."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "http_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access backend HTTP traffic for Caddy redirects and certificate issuance."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "https_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access backend HTTPS traffic through Caddy."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 30
}

variable "parameter_store_path" {
  description = "SSM Parameter Store path for Saynow production environment variables."
  type        = string
  default     = "/saynow/prod"

  validation {
    condition     = startswith(var.parameter_store_path, "/") && !endswith(var.parameter_store_path, "/")
    error_message = "parameter_store_path must start with '/' and must not end with '/'."
  }
}
