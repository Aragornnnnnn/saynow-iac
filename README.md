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
