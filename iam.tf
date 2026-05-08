data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backend" {
  name               = "${local.name_prefix}-backend-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${local.name_prefix}-backend-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "backend_ssm" {
  role       = aws_iam_role.backend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "backend_parameter_store_read" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]

    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.parameter_store_path}/*",
    ]
  }
}

resource "aws_iam_role_policy" "backend_parameter_store_read" {
  name   = "${local.name_prefix}-backend-parameter-store-read"
  role   = aws_iam_role.backend.id
  policy = data.aws_iam_policy_document.backend_parameter_store_read.json
}

resource "aws_iam_instance_profile" "backend" {
  name = "${local.name_prefix}-backend-instance-profile"
  role = aws_iam_role.backend.name

  tags = {
    Name = "${local.name_prefix}-backend-instance-profile"
  }
}
