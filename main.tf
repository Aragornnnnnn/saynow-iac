resource "aws_key_pair" "deploy" {
  key_name   = "${local.name_prefix}-deploy-key"
  public_key = var.ssh_public_key

  tags = {
    Name = "${local.name_prefix}-deploy-key"
  }

  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "aws_instance" "backend" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.backend.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.backend.name
  key_name                    = aws_key_pair.deploy.key_name

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    app_port            = var.app_port
    backend_domain_name = var.backend_domain_name
    service_name        = local.service_name
  })

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${local.name_prefix}-backend"
  }

  lifecycle {
    ignore_changes = [
      ami,
      user_data,
    ]
  }
}

resource "aws_eip" "backend" {
  domain   = "vpc"
  instance = aws_instance.backend.id

  tags = {
    Name = "${local.name_prefix}-backend-eip"
  }
}
