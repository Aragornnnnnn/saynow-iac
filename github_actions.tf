variable "github_actions_backend_repository" {
  description = "GitHub repository allowed to assume the backend deployment role."
  type        = string
  default     = "Aragornnnnnn/saynow-be"
}

variable "github_actions_backend_branch" {
  description = "GitHub branch allowed to assume the backend deployment role."
  type        = string
  default     = "main"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
  ]

  tags = {
    Name = "${local.name_prefix}-github-actions-oidc"
  }
}

data "aws_iam_policy_document" "github_actions_backend_deploy_assume_role" {
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
        "repo:${var.github_actions_backend_repository}:ref:refs/heads/${var.github_actions_backend_branch}",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_backend_deploy" {
  name               = "${local.name_prefix}-github-actions-backend-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_backend_deploy_assume_role.json

  tags = {
    Name = "${local.name_prefix}-github-actions-backend-deploy"
  }
}

data "aws_iam_policy_document" "github_actions_backend_deploy" {
  statement {
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]

    resources = [
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:security-group/${aws_security_group.backend.id}",
    ]
  }

  statement {
    actions = [
      "ec2:DescribeSecurityGroups",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_backend_deploy" {
  name   = "${local.name_prefix}-github-actions-backend-deploy"
  role   = aws_iam_role.github_actions_backend_deploy.id
  policy = data.aws_iam_policy_document.github_actions_backend_deploy.json
}
