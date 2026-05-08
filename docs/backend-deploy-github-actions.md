# Backend GitHub Actions Deployment to EC2

The EC2 instance created by this IAC repository runs a systemd service named `saynow-backend`.

## Required GitHub Secrets in the backend repository

- `EC2_HOST`: value from `terraform output -raw backend_public_ip`
- `EC2_SSH_PRIVATE_KEY`: private key matching `ssh_public_key` in `environments/prod-saynow.tfvars`

`EC2_HOST` is backed by an Elastic IP, so it should stay stable unless the Terraform Elastic IP resource is replaced or destroyed.

## Production environment variables

Production variables are stored in AWS Systems Manager Parameter Store under `/saynow/prod`.

Required parameters:

- `/saynow/prod/DB_URL`
- `/saynow/prod/DB_USERNAME`
- `/saynow/prod/DB_PASSWORD`

Use `SecureString` for all three values. Do not put the plaintext values in this repository, Terraform files, workflow YAML, or chat.

The EC2 instance role can read parameters under `/saynow/prod/*`. The deployment workflow does not need AWS access keys for this; it fetches parameters from inside the EC2 instance using the instance profile.

## SSH access requirement

This repository defaults `ssh_allowed_cidr_blocks` to an empty list, so port `22` is not open after the initial apply.

Before using the SSH deployment workflow, add an intentionally scoped CIDR block to `environments/prod-saynow.tfvars` and run `terraform plan` and `terraform apply` again. Do not open SSH to `0.0.0.0/0`.

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

      - name: Sync production environment
        run: |
          ssh -i ~/.ssh/saynow-prod-deploy ec2-user@${{ secrets.EC2_HOST }} <<'SCRIPT'
          set -euo pipefail

          TMP_ENV="$(mktemp)"
          aws ssm get-parameters-by-path \
            --path /saynow/prod \
            --with-decryption \
            --recursive \
            --query 'Parameters[*].[Name,Value]' \
            --output text |
          while IFS=$'\t' read -r NAME VALUE; do
            KEY="${NAME##*/}"
            ESCAPED_VALUE="${VALUE//\\/\\\\}"
            ESCAPED_VALUE="${ESCAPED_VALUE//\"/\\\"}"
            printf '%s="%s"\n' "$KEY" "$ESCAPED_VALUE"
          done > "$TMP_ENV"

          sudo install -o root -g saynow -m 0640 "$TMP_ENV" /opt/saynow/.env.prod
          rm -f "$TMP_ENV"
          SCRIPT

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
