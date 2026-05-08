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

## Terraform Backend

Terraform state is stored in S3 with native S3 lockfile-based locking.

```text
Bucket: saynow-prod-terraform-state-494873119837
Key: prod/saynow-iac/terraform.tfstate
Region: ap-northeast-2
Lock file: prod/saynow-iac/terraform.tfstate.tflock
```

The backend bucket is bootstrapped outside this root Terraform state and has versioning, default encryption, public access block, and an HTTPS-only bucket policy enabled.

Do not switch back to local state for production changes.

## Elastic IP

The backend EC2 instance uses an Elastic IP so `backend_public_ip`, `backend_public_dns`, `backend_app_url`, and `backend_ssh_command` stay stable across instance stop/start cycles.

Do not leave allocated Elastic IPs unattached. AWS charges for public IPv4 usage, and idle Elastic IPs can create avoidable cost.

## Production Environment Variables

Application environment variables are stored in AWS Systems Manager Parameter Store using the `/saynow/{environment}` path pattern.

Current production parameters use `/saynow/prod`. Future development parameters should use `/saynow/dev`.

Use `SecureString` for secrets and keep the standard tier unless a value is larger than the standard tier limit.

```bash
AWS_PROFILE=prod-saynow aws ssm put-parameter \
  --name /saynow/prod/DB_URL \
  --type SecureString \
  --value '<prod-db-url>' \
  --tier Standard \
  --overwrite

AWS_PROFILE=prod-saynow aws ssm put-parameter \
  --name /saynow/prod/DB_USERNAME \
  --type SecureString \
  --value '<prod-db-username>' \
  --tier Standard \
  --overwrite

AWS_PROFILE=prod-saynow aws ssm put-parameter \
  --name /saynow/prod/DB_PASSWORD \
  --type SecureString \
  --value '<prod-db-password>' \
  --tier Standard \
  --overwrite
```

Do not manage real secret values with Terraform. Terraform state can retain parameter values when `aws_ssm_parameter` resources are used.
