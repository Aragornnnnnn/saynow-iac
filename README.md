# saynow-iac

Saynow MVP 인프라를 관리하는 Terraform 저장소입니다.

## AWS 프로필

production 인프라 명령은 모두 `prod-saynow` AWS profile을 사용합니다.

```bash
AWS_PROFILE=prod-saynow aws sts get-caller-identity
```

기대 계정:

```text
494873119837
```

## 로컬 Terraform 실행 흐름

```bash
terraform fmt -recursive
AWS_PROFILE=prod-saynow terraform init
AWS_PROFILE=prod-saynow terraform validate
AWS_PROFILE=prod-saynow terraform plan -var-file=environments/prod-saynow.tfvars -out=prod-saynow.tfplan
AWS_PROFILE=prod-saynow terraform apply prod-saynow.tfplan
```

`terraform plan` 실행 전 실제 배포용 public key를 넣은 `environments/prod-saynow.tfvars`를 준비해야 합니다.

실제 `*.tfvars`, Terraform state, plan 파일은 커밋하지 않습니다. `terraform init` 후 생성되는 `.terraform.lock.hcl`은 커밋합니다.

## Terraform Backend

Terraform state는 S3에 저장하고, locking은 S3 native lockfile을 사용합니다.

```text
Bucket: saynow-prod-terraform-state-494873119837
Key: prod/saynow-iac/terraform.tfstate
Region: ap-northeast-2
Lock file: prod/saynow-iac/terraform.tfstate.tflock
```

backend bucket은 이 루트 Terraform state 밖에서 bootstrap합니다. 현재 versioning, 기본 암호화, public access block, HTTPS-only bucket policy가 적용되어 있습니다.

production 변경 작업에서 local state로 되돌리지 않습니다.

## Elastic IP

백엔드 EC2 인스턴스는 Elastic IP를 사용합니다. 따라서 인스턴스를 stop/start해도 `backend_public_ip`, `backend_public_dns`, `backend_app_url`, `backend_ssh_command` 값이 안정적으로 유지됩니다.

할당된 Elastic IP를 미연결 상태로 방치하지 않습니다. AWS는 public IPv4 사용량에 과금하며, idle Elastic IP는 불필요한 비용을 만들 수 있습니다.

## Backend HTTPS

백엔드 public endpoint는 `https://saynow.p-e.kr`입니다. 도메인의 A record는 `terraform output -raw backend_public_ip` 값으로 관리합니다.

백엔드 EC2 보안그룹은 public application traffic으로 TCP `80`과 `443`만 엽니다. Spring Boot는 기존처럼 EC2 내부 `8080` 포트에서 실행하고, Caddy가 `saynow.p-e.kr` 요청을 `127.0.0.1:8080`으로 reverse proxy합니다.

`user_data.sh.tftpl`은 새로 생성되는 백엔드 EC2에 Caddy를 설치하고 `/etc/caddy/Caddyfile`을 작성합니다. 이미 실행 중인 EC2에는 user data가 자동 재실행되지 않으므로, 기존 인스턴스에는 동일한 Caddy 설정을 수동으로 적용하거나 인스턴스 교체 계획을 별도로 세웁니다.

Terraform 변경 적용 후 확인합니다.

```bash
curl -I http://saynow.p-e.kr
curl -I https://saynow.p-e.kr
```

## Production 환경변수

애플리케이션 환경변수는 AWS Systems Manager Parameter Store에 `/saynow/{environment}` 경로 규칙으로 저장합니다.

현재 production parameter는 `/saynow/prod`를 사용합니다. 이후 development parameter는 `/saynow/dev`를 사용합니다.

secret 값은 `SecureString`을 사용합니다. 값이 standard tier 제한보다 크지 않다면 standard tier를 유지합니다.

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

실제 secret 값은 Terraform으로 관리하지 않습니다. `aws_ssm_parameter` 리소스를 사용하면 Terraform state에 parameter 값이 남을 수 있습니다.
