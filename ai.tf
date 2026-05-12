data "aws_iam_policy_document" "ai_backend_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ai_backend" {
  name               = "${local.name_prefix}-ai-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ai_backend_assume_role.json

  tags = {
    Name = "${local.name_prefix}-ai-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ai_backend_ssm" {
  role       = aws_iam_role.ai_backend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "ai_backend_parameter_store_read" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]

    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.parameter_store_path}",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.parameter_store_path}/*",
    ]
  }
}

resource "aws_iam_role_policy" "ai_backend_parameter_store_read" {
  name   = "${local.name_prefix}-ai-parameter-store-read"
  role   = aws_iam_role.ai_backend.id
  policy = data.aws_iam_policy_document.ai_backend_parameter_store_read.json
}

resource "aws_iam_instance_profile" "ai_backend" {
  name = "${local.name_prefix}-ai-instance-profile"
  role = aws_iam_role.ai_backend.name

  tags = {
    Name = "${local.name_prefix}-ai-instance-profile"
  }
}

resource "aws_security_group" "ai_backend" {
  name_prefix = "${local.name_prefix}-ai-"
  description = "Security group for the Saynow FastAPI AI EC2 instance."
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
    description = "FastAPI application traffic"
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
    Name = "${local.name_prefix}-ai-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "ai_backend" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.ai_backend.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ai_backend.name
  key_name                    = aws_key_pair.deploy.key_name

  user_data = templatefile("${path.module}/ai_user_data.sh.tftpl", {
    app_port     = var.app_port
    service_name = local.ai_service_name
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
    Name = "${local.name_prefix}-ai-backend"
  }

  lifecycle {
    ignore_changes = [
      ami,
      user_data,
    ]
  }
}

resource "aws_eip" "ai_backend" {
  domain   = "vpc"
  instance = aws_instance.ai_backend.id

  tags = {
    Name = "${local.name_prefix}-ai-backend-eip"
  }
}

variable "github_actions_ai_repository" {
  description = "GitHub repository allowed to assume the AI deployment role."
  type        = string
  default     = "Aragornnnnnn/saynow-ai"
}

variable "github_actions_ai_environment" {
  description = "GitHub environment allowed to assume the AI deployment role."
  type        = string
  default     = "prod"
}

data "aws_iam_policy_document" "github_actions_ai_deploy_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_actions_ai_repository}:environment:${var.github_actions_ai_environment}",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_ai_deploy" {
  name               = "${local.name_prefix}-github-actions-ai-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_ai_deploy_assume_role.json

  tags = {
    Name = "${local.name_prefix}-github-actions-ai-deploy"
  }
}

data "aws_iam_policy_document" "github_actions_ai_deploy" {
  statement {
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]

    resources = [
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:security-group/${aws_security_group.ai_backend.id}",
    ]
  }

  statement {
    actions   = ["ec2:DescribeSecurityGroups"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_ai_deploy" {
  name   = "${local.name_prefix}-github-actions-ai-deploy"
  role   = aws_iam_role.github_actions_ai_deploy.id
  policy = data.aws_iam_policy_document.github_actions_ai_deploy.json
}
