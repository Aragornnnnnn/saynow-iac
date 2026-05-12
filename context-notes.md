# Backend HTTPS Caddy Context Notes

## 2026-05-12

- 사용자는 `saynow.p-e.kr` 도메인을 등록했고, 도메인의 IP도 백엔드 EC2 Elastic IP로 등록했다고 설명했다.
- 이번 작업의 목표는 백엔드 EC2 앞단에 Caddy를 두어 HTTPS 요청을 Spring Boot 로컬 포트로 프록시하는 것이다.
- Terraform은 AWS 리소스의 실제 공개 경계를 관리한다. 따라서 보안그룹의 public ingress와 `backend_app_url` output은 Terraform 변경 대상이다.
- Spring Boot 서비스는 기존처럼 `8080`에서 실행하되, 외부에서 `8080`으로 직접 접근하는 보안그룹 규칙은 제거한다.
- Caddy는 EC2 내부 구성 요소지만, 인스턴스 재생성 시 같은 상태가 되도록 `user_data.sh.tftpl`에 설치와 Caddyfile 생성을 포함한다.
- `app_allowed_cidr_blocks`는 AI EC2 보안그룹에서도 사용 중이므로 제거하지 않고, 백엔드 보안그룹만 별도의 `http_allowed_cidr_blocks`와 `https_allowed_cidr_blocks`로 분리한다.
- `AWS_PROFILE=prod-saynow terraform validate`는 provider plugin 실행 문제 때문에 sandbox 밖에서 재실행했고 성공했다.
- `AWS_PROFILE=prod-saynow terraform plan -var-file=environments/prod-saynow.tfvars`는 이 worktree에 실제 tfvars 파일이 없어서 실행되지 못했다. 이후 remote state에서 현재 key 값을 확인하려 했지만 S3 backend `prod/saynow-iac/terraform.tfstate` `HeadObject`가 `403 Forbidden`으로 막혔다.
- `AWS_PROFILE=prod-saynow aws sts get-caller-identity`는 account `494873119837`, user `codex-sm`으로 성공했으므로 현재 blocker는 인증 자체가 아니라 state object 읽기 권한이다.
- 사용자의 apply 요청 후 실제 tfvars를 `/Users/sangmin8817/Desktop/Soma/saynow-iac/environments/prod-saynow.tfvars`에서 찾아 plan을 실행했다. 최초 plan은 최신 AMI 재조회, user data 변경, public key 차이 때문에 백엔드 EC2, AI EC2, deploy key 교체를 제안했으므로 중단했다.
- 운영 인스턴스 교체를 막기 위해 EC2 `ami`와 `user_data`, deploy key `public_key` 변경은 lifecycle에서 ignore한다. 기존 백엔드 EC2의 Caddy 설정은 `aws_ssm_document`와 `aws_ssm_association`으로 적용한다.
- Caddy COPR 설치는 Amazon Linux 2023에서 `amazonlinux-2023-x86_64` repository가 없어 실패했다. 공식 Caddy 문서의 static binary 설치 방식으로 전환하고 systemd unit을 직접 생성한다.
- static binary 설치 첫 실행은 `curl-minimal`과 `curl` 패키지 충돌 때문에 실패했다. Amazon Linux 2023 기본 `curl-minimal`의 `curl` 바이너리를 사용하고, 명시 설치 대상에서는 `curl`을 제거한다.
- 사용자 확인 후 targeted `terraform apply`를 두 번 실행했다. 첫 번째는 `aws_ssm_document.backend_caddy`와 `aws_ssm_association.backend_caddy` 생성 및 수정이고, 두 번째는 `aws_security_group.backend`에서 `80/443`만 public으로 열고 기존 `8080`과 `22` ingress를 제거한 변경이다.
- `terraform apply -refresh-only`로 `backend_app_url` output을 `https://saynow.p-e.kr`로 동기화했다.
- 적용 후 검증에서 백엔드 보안그룹은 `80`과 `443`만 열려 있고, `curl -I http://saynow.p-e.kr`는 Caddy `308` redirect, `curl -I https://saynow.p-e.kr`는 HTTPS 연결 성공, `/actuator/health`는 `200`과 `{"groups":["liveness","readiness"],"status":"UP"}`를 반환했다.
- `curl -I http://13.209.216.213:8080`은 timeout으로 실패해 외부 `8080` 직접 접근이 닫힌 것을 확인했다.
- 최종 full plan에는 HTTPS 작업과 무관한 AI 보안그룹의 기존 SSH ingress 제거 및 그에 따른 AI GitHub Actions IAM policy 갱신만 남아 있다. 이 변경은 이번 apply에서 제외했다.
