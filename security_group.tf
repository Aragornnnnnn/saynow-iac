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
    description = "HTTP traffic for Caddy redirects and certificate issuance"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.http_allowed_cidr_blocks
  }

  ingress {
    description = "HTTPS traffic for Caddy reverse proxy"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.https_allowed_cidr_blocks
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
