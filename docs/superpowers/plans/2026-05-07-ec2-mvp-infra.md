# EC2 MVP Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `prod-saynow` AWS 계정에 Java/Spring 백엔드 배포용 단일 EC2 MVP 인프라를 Terraform으로 구축한다.

**Architecture:** 루트 Terraform 구성 하나로 기본 VPC의 퍼블릭 서브넷에 Amazon Linux 2023 기반 `t3.micro` EC2를 만든다. EC2 운영에 필요한 Security Group, SSH Key Pair, SSM용 IAM Instance Profile, Java 21/systemd 초기 설정만 포함하고, ALB/RDS/ECR/S3/도메인은 MVP 범위에서 제외한다. 백엔드 CI/CD는 별도 애플리케이션 레포의 GitHub Actions가 빌드한 JAR를 EC2에 업로드하고 systemd 서비스를 재시작하는 방식으로 연결한다.

**Tech Stack:** Terraform 1.14.1, AWS Provider `>= 5.0, < 7.0`, AWS profile `prod-saynow`, AWS region `ap-northeast-2`, Amazon Linux 2023, Java 21, systemd, GitHub Actions

---

## Assumptions

- `EC2만 만든다`는 말은 ALB/RDS/ECR/S3 같은 별도 서비스는 만들지 않고, EC2 구동에 필요한 보안 그룹, IAM role, key pair 같은 필수 부속 리소스만 만든다는 의미로 해석한다.
- 이 레포는 현재 비어 있으므로 기존 Terraform 모듈 패턴 없이 루트 모듈부터 만든다.
- 백엔드 배포 CI/CD는 애플리케이션 레포에 둘 예정이며, 이 IAC 레포는 EC2 접속 정보와 systemd 실행 환경을 제공한다.
- GitHub-hosted runner에서 SSH 배포를 하려면 runner 출발지 IP가 유동적이다. MVP에서는 `ssh_allowed_cidr_blocks`를 명시적으로 관리하고, 운영 배포가 안정화되면 SSM 기반 배포나 고정 egress runner로 전환한다.

## File Structure

- Create: `.gitignore` - Terraform 로컬 상태, plan 파일, 민감한 tfvars, macOS 메타파일 제외
- Create: `README.md` - 로컬 실행 절차와 `prod-saynow` profile 사용 규칙 문서화
- Create: `versions.tf` - Terraform/AWS provider 버전 제약
- Create: `variables.tf` - 프로젝트, 리전, EC2, 방화벽, SSH public key 변수 정의
- Create: `locals.tf` - 공통 이름, 태그, systemd service 이름
- Create: `providers.tf` - AWS provider와 default tags
- Create: `data.tf` - 기본 VPC, 기본 서브넷, Amazon Linux 2023 AMI 조회
- Create: `security_group.tf` - 8080 앱 포트와 22 SSH ingress, 전체 egress
- Create: `iam.tf` - EC2용 IAM role, SSM managed policy, instance profile
- Create: `main.tf` - SSH key pair와 EC2 instance
- Create: `user_data.sh.tftpl` - Java 21 설치, `/opt/saynow`, systemd service 생성
- Create: `outputs.tf` - EC2 public IP/DNS, SSH command, app URL 출력
- Create: `environments/prod-saynow.tfvars.example` - 커밋 가능한 예시 값
- Create: `docs/backend-deploy-github-actions.md` - Spring Boot JAR를 EC2로 배포하는 GitHub Actions 예시

---

### Task 1: Repository Terraform Scaffold

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: `versions.tf`
- Create: `providers.tf`
- Create: `locals.tf`

- [x] **Step 1: Create `.gitignore`**

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
*.auto.tfvars
*.auto.tfvars.json
*.tfvars
*.tfvars.json
.DS_Store
```

- [x] **Step 2: Create `README.md`**

````markdown
# saynow-iac

Terraform infrastructure for the Saynow MVP.

## AWS Profile

Use the `prod-saynow` AWS profile for all production infrastructure commands.

```bash
AWS_PROFILE=prod-saynow aws sts get-caller-identity
```

Expected account:

```text
494873119837
```

## Local Terraform Flow

```bash
terraform fmt -recursive
AWS_PROFILE=prod-saynow terraform init
AWS_PROFILE=prod-saynow terraform validate
AWS_PROFILE=prod-saynow terraform plan -var-file=environments/prod-saynow.tfvars -out=prod-saynow.tfplan
AWS_PROFILE=prod-saynow terraform apply prod-saynow.tfplan
```

Create `environments/prod-saynow.tfvars` with a real deploy public key before running `terraform plan`.

Do not commit real `*.tfvars`, Terraform state, or plan files. Commit `.terraform.lock.hcl` after `terraform init`.
````

- [x] **Step 3: Create `versions.tf`**

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}
```

- [x] **Step 4: Create `locals.tf`**

```hcl
locals {
  name_prefix  = "${var.environment}-${var.project_name}"
  service_name = "${var.project_name}-backend"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

- [x] **Step 5: Create `providers.tf`**

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
```

- [x] **Step 6: Format scaffold files**

Run:

```bash
terraform fmt -recursive
```

Expected: command exits `0`; no Terraform validation yet because variables and resources are not complete.

- [x] **Step 7: Commit scaffold**

```bash
git add .gitignore README.md versions.tf providers.tf locals.tf
git commit -m "main feat: Terraform 기본 구조 추가"
```

---

### Task 2: Variables and AWS Data Sources

**Files:**
- Create: `variables.tf`
- Create: `data.tf`
- Create: `environments/prod-saynow.tfvars.example`

- [x] **Step 1: Create `variables.tf`**

```hcl
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
```

- [x] **Step 2: Create `data.tf`**

```hcl
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
```

- [x] **Step 3: Create `environments/prod-saynow.tfvars.example`**

```hcl
aws_region              = "ap-northeast-2"
project_name            = "saynow"
environment             = "prod"
instance_type           = "t3.micro"
app_port                = 8080
app_allowed_cidr_blocks = ["0.0.0.0/0"]
ssh_allowed_cidr_blocks = []
root_volume_size        = 8
ssh_public_key          = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExamplePublicKeyForDocumentationOnly saynow-prod-deploy"
```

- [x] **Step 4: Create local untracked `environments/prod-saynow.tfvars`**

Run:

```bash
ssh-keygen -t ed25519 -C saynow-prod-deploy -f ~/.ssh/saynow-prod-deploy
cp environments/prod-saynow.tfvars.example environments/prod-saynow.tfvars
```

Run:

```bash
PUBLIC_KEY="$(cat ~/.ssh/saynow-prod-deploy.pub)"
cat > environments/prod-saynow.tfvars <<EOF
aws_region              = "ap-northeast-2"
project_name            = "saynow"
environment             = "prod"
instance_type           = "t3.micro"
app_port                = 8080
app_allowed_cidr_blocks = ["0.0.0.0/0"]
ssh_allowed_cidr_blocks = []
root_volume_size        = 8
ssh_public_key          = "$PUBLIC_KEY"
EOF
```

Expected: `git status --short` does not show `environments/prod-saynow.tfvars` because `*.tfvars` is ignored.

- [x] **Step 5: Format and commit**

```bash
terraform fmt -recursive
git add variables.tf data.tf environments/prod-saynow.tfvars.example
git commit -m "main feat: prod EC2 변수와 데이터 소스 추가"
```

---

### Task 3: Security Group

**Files:**
- Create: `security_group.tf`

- [ ] **Step 1: Create `security_group.tf`**

```hcl
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
```

- [ ] **Step 2: Validate security group configuration**

Run:

```bash
terraform fmt -recursive
AWS_PROFILE=prod-saynow terraform init
AWS_PROFILE=prod-saynow terraform validate
```

Expected: `terraform validate` prints `Success! The configuration is valid.`

- [ ] **Step 3: Commit security group**

```bash
git add security_group.tf .terraform.lock.hcl
git commit -m "main feat: EC2 보안 그룹 추가"
```

---

### Task 4: EC2 IAM Role for SSM

**Files:**
- Create: `iam.tf`

- [ ] **Step 1: Create `iam.tf`**

```hcl
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

resource "aws_iam_instance_profile" "backend" {
  name = "${local.name_prefix}-backend-instance-profile"
  role = aws_iam_role.backend.name

  tags = {
    Name = "${local.name_prefix}-backend-instance-profile"
  }
}
```

- [ ] **Step 2: Validate IAM configuration**

Run:

```bash
terraform fmt -recursive
AWS_PROFILE=prod-saynow terraform validate
```

Expected: `terraform validate` prints `Success! The configuration is valid.`

- [ ] **Step 3: Commit IAM resources**

```bash
git add iam.tf
git commit -m "main feat: EC2 SSM IAM 역할 추가"
```

---

### Task 5: EC2 Instance and Bootstrap

**Files:**
- Create: `user_data.sh.tftpl`
- Create: `main.tf`
- Create: `outputs.tf`

- [ ] **Step 1: Create `user_data.sh.tftpl`**

```bash
#!/bin/bash
set -euo pipefail

dnf update -y
dnf install -y java-21-amazon-corretto-headless

id saynow >/dev/null 2>&1 || useradd --system --home-dir /opt/saynow --shell /sbin/nologin saynow

mkdir -p /opt/saynow
chown saynow:saynow /opt/saynow
chmod 755 /opt/saynow

cat >/etc/systemd/system/${service_name}.service <<SERVICE
[Unit]
Description=Saynow Spring Boot backend
After=network-online.target
Wants=network-online.target

[Service]
User=saynow
Group=saynow
WorkingDirectory=/opt/saynow
Environment=SERVER_PORT=${app_port}
ExecStart=/usr/bin/java -jar /opt/saynow/app.jar
SuccessExitStatus=143
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable ${service_name}
```

- [ ] **Step 2: Create `main.tf`**

```hcl
resource "aws_key_pair" "deploy" {
  key_name   = "${local.name_prefix}-deploy-key"
  public_key = var.ssh_public_key

  tags = {
    Name = "${local.name_prefix}-deploy-key"
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
    app_port     = var.app_port
    service_name = local.service_name
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
}
```

- [ ] **Step 3: Create `outputs.tf`**

```hcl
output "backend_instance_id" {
  description = "EC2 instance id for the Saynow backend."
  value       = aws_instance.backend.id
}

output "backend_public_ip" {
  description = "Public IPv4 address for the Saynow backend EC2 instance."
  value       = aws_instance.backend.public_ip
}

output "backend_public_dns" {
  description = "Public DNS name for the Saynow backend EC2 instance."
  value       = aws_instance.backend.public_dns
}

output "backend_app_url" {
  description = "Direct MVP URL for the Spring Boot backend."
  value       = "http://${aws_instance.backend.public_ip}:${var.app_port}"
}

output "backend_ssh_command" {
  description = "SSH command for EC2 access when the caller is allowed by ssh_allowed_cidr_blocks."
  value       = "ssh -i ~/.ssh/saynow-prod-deploy ec2-user@${aws_instance.backend.public_ip}"
}

output "backend_service_name" {
  description = "systemd service name used for backend deployments."
  value       = local.service_name
}
```

- [ ] **Step 4: Run local validation**

```bash
terraform fmt -recursive
AWS_PROFILE=prod-saynow terraform validate
```

Expected: `terraform validate` prints `Success! The configuration is valid.`

- [ ] **Step 5: Commit EC2 resources**

```bash
git add main.tf outputs.tf user_data.sh.tftpl
git commit -m "main feat: Spring 백엔드 EC2 추가"
```

---

### Task 6: Terraform Plan and Double Check

**Files:**
- Read: all Terraform files

- [ ] **Step 1: Confirm AWS identity**

Run:

```bash
AWS_PROFILE=prod-saynow aws sts get-caller-identity --output json
```

Expected account:

```json
{
  "Account": "494873119837"
}
```

- [ ] **Step 2: Initialize Terraform**

Run:

```bash
AWS_PROFILE=prod-saynow terraform init
```

Expected: provider installation completes and Terraform reports successful initialization.

- [ ] **Step 3: Run Terraform plan**

Run:

```bash
AWS_PROFILE=prod-saynow terraform plan -var-file=environments/prod-saynow.tfvars -out=prod-saynow.tfplan
```

Expected: plan contains only these new resource types:

```text
aws_security_group.backend
aws_iam_role.backend
aws_iam_role_policy_attachment.backend_ssm
aws_iam_instance_profile.backend
aws_key_pair.deploy
aws_instance.backend
```

- [ ] **Step 4: Double check free-tier and exposure constraints**

Confirm from the plan:

```text
instance_type = "t3.micro"
volume_size   = 8
volume_type   = "gp3"
http_tokens   = "required"
from_port     = 8080
to_port       = 8080
```

Confirm SSH ingress is either absent or intentionally scoped:

```text
from_port = 22
to_port   = 22
```

If `cidr_blocks = ["0.0.0.0/0"]` appears for port 22, stop and replace `ssh_allowed_cidr_blocks` with a narrower CIDR before apply.

- [ ] **Step 5: Apply after the double check passes**

Run:

```bash
AWS_PROFILE=prod-saynow terraform apply prod-saynow.tfplan
```

Expected: Terraform creates the EC2 MVP resources and prints `backend_public_ip`, `backend_app_url`, and `backend_ssh_command`.

- [ ] **Step 6: Verify EC2 is reachable through AWS APIs**

Run:

```bash
AWS_PROFILE=prod-saynow aws ec2 describe-instances \
  --instance-ids "$(terraform output -raw backend_instance_id)" \
  --query 'Reservations[0].Instances[0].{State:State.Name,Type:InstanceType,PublicIp:PublicIpAddress}' \
  --output table
```

Expected:

```text
State      running
Type       t3.micro
```

---

### Task 7: Backend Deployment CI/CD Handoff

**Files:**
- Create: `docs/backend-deploy-github-actions.md`

- [ ] **Step 1: Create deployment guide**

````markdown
# Backend GitHub Actions Deployment to EC2

The EC2 instance created by this IAC repository runs a systemd service named `saynow-backend`.

## Required GitHub Secrets in the backend repository

- `EC2_HOST`: value from `terraform output -raw backend_public_ip`
- `EC2_SSH_PRIVATE_KEY`: private key matching `ssh_public_key` in `environments/prod-saynow.tfvars`

## Workflow

Create `.github/workflows/deploy-prod.yml` in the backend repository:

```yaml
name: Deploy production backend

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 20

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: corretto
          java-version: "21"

      - name: Build boot jar
        run: |
          chmod +x ./gradlew
          ./gradlew clean bootJar
          JAR_PATH="$(find build/libs -maxdepth 1 -type f -name '*.jar' ! -name '*-plain.jar' -print -quit)"
          test -n "$JAR_PATH"
          cp "$JAR_PATH" app.jar

      - name: Configure SSH
        run: |
          mkdir -p ~/.ssh
          printf '%s\n' "${{ secrets.EC2_SSH_PRIVATE_KEY }}" > ~/.ssh/saynow-prod-deploy
          chmod 600 ~/.ssh/saynow-prod-deploy
          ssh-keyscan -H "${{ secrets.EC2_HOST }}" >> ~/.ssh/known_hosts

      - name: Upload jar
        run: |
          scp -i ~/.ssh/saynow-prod-deploy app.jar ec2-user@${{ secrets.EC2_HOST }}:/tmp/saynow-app.jar

      - name: Restart service
        run: |
          ssh -i ~/.ssh/saynow-prod-deploy ec2-user@${{ secrets.EC2_HOST }} <<'SCRIPT'
          sudo install -o saynow -g saynow -m 0644 /tmp/saynow-app.jar /opt/saynow/app.jar
          sudo systemctl restart saynow-backend
          sudo systemctl --no-pager --full status saynow-backend
          SCRIPT
```

## Post-deploy check

```bash
ssh -i ~/.ssh/saynow-prod-deploy ec2-user@"$(terraform output -raw backend_public_ip)" \
  'sudo systemctl is-active saynow-backend'
```
````

- [ ] **Step 2: Commit deployment guide**

```bash
git add docs/backend-deploy-github-actions.md
git commit -m "main docs: 백엔드 EC2 배포 가이드 추가"
```

---

## Out of Scope for MVP

- ALB, HTTPS 인증서, Route 53 도메인
- RDS, ElastiCache, S3 artifact bucket, ECR
- Blue/green deployment
- Auto Scaling Group
- Private subnet/NAT 기반 운영망
- Centralized logging/metrics

## Self-Review

- Spec coverage: `t3.micro` EC2, Java/Spring 실행 환경, Terraform 인프라, `prod-saynow` profile 사용, CI/CD 연결 방식을 모두 포함했다.
- Placeholder scan: 실제 구현 파일에는 미정 상태를 나타내는 키워드를 넣지 않는다. `prod-saynow.tfvars.example`의 public key는 커밋 가능한 문서용 예시이며, 실제 적용 파일은 `*.tfvars` ignore 규칙으로 커밋하지 않는다.
- Type consistency: `local.service_name`은 `saynow-backend`로 user data, output, 배포 가이드에서 동일하게 사용한다. 앱 포트는 `var.app_port` 기본값 `8080`으로 security group, user data, output, health check가 일치한다.
