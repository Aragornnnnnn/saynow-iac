# Backend GitHub Actions Deployment to EC2

The EC2 instance created by this IAC repository runs a systemd service named `saynow-backend`.

## Required GitHub Secrets in the backend repository

- `EC2_SSH_KEY`: private key matching `ssh_public_key` in `environments/prod-saynow.tfvars`

`EC2_HOST` is backed by an Elastic IP, so it should stay stable unless the Terraform Elastic IP resource is replaced or destroyed.

## Required GitHub Variables in the backend repository

- `EC2_HOST`: value from `terraform output -raw backend_public_ip`
- `EC2_USER`: `ec2-user`
- `AWS_REGION`: `ap-northeast-2`
- `AWS_ROLE_ARN`: value from `terraform output -raw backend_github_actions_deploy_role_arn`
- `EC2_SECURITY_GROUP_ID`: value from `terraform output -raw backend_security_group_id`

## Production environment variables

Production variables are stored in AWS Systems Manager Parameter Store under `/saynow/prod`.

Environment paths are separated by environment:

- Production: `/saynow/prod`
- Development: `/saynow/dev`

Required parameters:

- `/saynow/prod/DB_URL`
- `/saynow/prod/DB_USERNAME`
- `/saynow/prod/DB_PASSWORD`

Use `SecureString` for all three values. Do not put the plaintext values in this repository, Terraform files, workflow YAML, or chat.

The production EC2 instance role can read parameters under `/saynow/prod/*`. The deployment workflow does not need AWS access keys for this; it fetches parameters from inside the EC2 instance using the instance profile.

## SSH access requirement

This repository defaults `ssh_allowed_cidr_blocks` to an empty list, so port `22` is not open after the initial apply.

For GitHub-hosted runners, do not permanently open SSH to `0.0.0.0/0`. Their egress IPs are dynamic, so the safer pattern is to let the deployment workflow temporarily authorize the current runner public IP as `/32` before `ssh-keyscan`, then revoke the rule in an `always()` cleanup step.

The backend deployment job uses the GitHub environment named `prod`. For that reason, the AWS OIDC trust policy allows the subject `repo:Aragornnnnnn/saynow-be:environment:prod`. Keep the GitHub `prod` environment deployment branch policy restricted to `main`.

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
    environment: prod
    timeout-minutes: 20
    permissions:
      contents: read
      id-token: write

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

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
          role-session-name: saynow-be-${{ github.run_id }}

      - name: Authorize runner SSH ingress
        id: runner-ip
        run: |
          set -euo pipefail
          RUNNER_IP="$(curl -fsS https://checkip.amazonaws.com | tr -d '\n')"
          test -n "$RUNNER_IP"
          echo "cidr=${RUNNER_IP}/32" >> "$GITHUB_OUTPUT"

          aws ec2 authorize-security-group-ingress \
            --group-id "${{ vars.EC2_SECURITY_GROUP_ID }}" \
            --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${RUNNER_IP}/32,Description=github-actions-${{ github.run_id }}}]" || true

      - name: Configure SSH
        run: |
          mkdir -p ~/.ssh
          printf '%s\n' "${{ secrets.EC2_SSH_KEY }}" > ~/.ssh/saynow-prod-deploy
          chmod 600 ~/.ssh/saynow-prod-deploy
          ssh-keyscan -H "${{ vars.EC2_HOST }}" >> ~/.ssh/known_hosts

      - name: Upload jar
        run: |
          scp -i ~/.ssh/saynow-prod-deploy app.jar ${{ vars.EC2_USER }}@${{ vars.EC2_HOST }}:/tmp/saynow-app.jar

      - name: Sync production environment
        run: |
          ssh -i ~/.ssh/saynow-prod-deploy ${{ vars.EC2_USER }}@${{ vars.EC2_HOST }} <<'SCRIPT'
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
          ssh -i ~/.ssh/saynow-prod-deploy ${{ vars.EC2_USER }}@${{ vars.EC2_HOST }} <<'SCRIPT'
          sudo install -o saynow -g saynow -m 0644 /tmp/saynow-app.jar /opt/saynow/app.jar
          sudo systemctl restart saynow-backend
          sudo systemctl --no-pager --full status saynow-backend
          SCRIPT

      - name: Revoke runner SSH ingress
        if: always() && steps.runner-ip.outputs.cidr != ''
        run: |
          aws ec2 revoke-security-group-ingress \
            --group-id "${{ vars.EC2_SECURITY_GROUP_ID }}" \
            --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${{ steps.runner-ip.outputs.cidr }},Description=github-actions-${{ github.run_id }}}]" || true
```

## Post-deploy check

```bash
ssh -i ~/.ssh/saynow-prod-deploy ec2-user@"$(terraform output -raw backend_public_ip)" \
  'sudo systemctl is-active saynow-backend'
```
