# AGENTS.md

## 기본 원칙

- 한국어를 사용한다.
- 작업을 시작하기 전에 관련 문서와 계획 파일을 먼저 확인한다.
- 변경 범위는 요청된 작업에 맞게 작게 유지하고, 관련 없는 파일은 수정하지 않는다.
- 작업 사항에 대해서는 완료 전 double check를 수행한다.
- 기능, 인프라 구조, 실행 절차, 검증 방법, 보안/운영 규칙이 바뀌면 관련 문서와 함께 `AGENTS.md`도 최신 상태로 갱신한다.

## Git / Pull Request

- 커밋 메시지는 `{type}: {한글 커밋 메시지}` 형식을 따른다.
  - 예: `feat: 사용자 로그인 기능 추가`
- Pull Request를 작성할 때는 프로젝트 내에 PR Template가 존재하는지 먼저 확인하고, 존재한다면 해당 양식을 따른다.
- PR 본문에는 주요 변경 사항, 검증 결과, 남은 리스크를 간결하게 포함한다.

## 검증

- 변경 후 `git diff`와 `git status`로 의도하지 않은 변경이 없는지 확인한다.
- 코드나 설정을 수정한 경우 가능한 관련 포맷터, 린터, 테스트, validate/plan 명령을 실행한다.
- 검증 명령을 실행하지 못했다면 완료 보고에 이유와 남은 리스크를 명시한다.

## Terraform / IaC

- Terraform 파일을 수정한 뒤에는 `terraform fmt -recursive`를 실행한다.
- Terraform 변경은 가능한 한 `terraform validate`와 `terraform plan`으로 검증한 뒤 보고한다.
- production 인프라 작업은 `prod-saynow` AWS profile과 `ap-northeast-2` region 사용 여부를 확인한다.
- 실제 `*.tfvars`, Terraform state, plan 파일, 비밀 값, 접근 키는 커밋하지 않는다.
- production Terraform state는 S3 backend `saynow-prod-terraform-state-494873119837/prod/saynow-iac/terraform.tfstate`와 S3 native lockfile을 사용한다.
- 애플리케이션 환경변수는 환경별 `/saynow/{environment}` 경로의 SSM Parameter Store `SecureString`으로 관리하고, 실제 secret 값을 Terraform 리소스로 만들지 않는다.
- 백엔드 public HTTPS는 EC2 내부 Caddy가 `80/443`에서 종료하고 Spring Boot `127.0.0.1:8080`으로 프록시한다. 백엔드 보안그룹에서 `8080`을 public으로 직접 열지 않는다.
- GitHub-hosted runner SSH 배포는 `Aragornnnnnn/saynow-be` Actions OIDC role로 실행 중인 runner IP만 `/32`로 임시 허용하고 종료 시 회수한다.
- `Aragornnnnnn/saynow-be` 배포 OIDC trust는 GitHub `prod` environment subject를 사용하므로, GitHub `prod` environment의 deployment branch policy를 `main`으로 제한한다.
- `terraform apply`, `terraform destroy`, 리소스 삭제/교체처럼 운영 인프라에 영향을 주는 작업은 실행 전에 사용자 확인을 받는다.

## 문서

- 실행 절차, 환경 변수, 운영 방식, 배포 방식이 달라지면 `README.md` 또는 `docs/` 하위 문서를 함께 갱신한다.
- `docs/superpowers/plans/` 하위 계획 파일을 실행할 때는 체크박스 상태와 실제 구현 상태가 어긋나지 않게 관리한다.
