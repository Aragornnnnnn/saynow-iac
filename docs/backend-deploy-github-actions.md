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
