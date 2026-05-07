resource "aws_security_group" "backend" {
  name_prefix = "${local.name_prefix}-backend-"
  description = "Security group for the Saynow Spring backend EC2 instance."
  vpc_id      = data.aws_vpc.default.id

  dynamic "ingress" {
    for_each = var.ssh_allowed_cidr_blocks

    content {
      description = "SSH access for deployment"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  ingress {
    description = "Spring Boot application traffic"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = var.app_allowed_cidr_blocks
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-backend-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
