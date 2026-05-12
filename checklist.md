# Backend HTTPS Caddy Checklist

- [x] 계획 파일 작성.
- [x] 컨텍스트 노트 작성.
- [x] Terraform 보안그룹을 80/443 공개 구조로 변경.
- [x] 8080 직접 공개 설정 제거.
- [x] Caddy 설치와 reverse proxy 설정을 EC2 user data에 반영.
- [x] 기존 백엔드 EC2에 Caddy를 적용할 SSM association 추가.
- [x] `backend_app_url`을 `https://saynow.p-e.kr`로 변경.
- [x] README와 배포 문서 갱신.
- [x] `terraform fmt -recursive` 실행.
- [x] `terraform validate` 실행.
- [x] `terraform plan` 실행. 최초 full plan은 EC2 교체가 잡혀 중단했고, 이후 targeted plan으로 Caddy SSM과 백엔드 보안그룹만 적용.
- [x] `git diff`와 `git status`로 변경 범위 확인.
- [x] 논리 단위 커밋 생성.
