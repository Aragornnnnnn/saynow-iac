# Backend HTTPS Caddy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose the production backend through `https://saynow.p-e.kr` using Caddy on the EC2 instance.

**Architecture:** Terraform keeps ownership of AWS-facing infrastructure such as security group ingress and published outputs. EC2 bootstrap installs Caddy and writes a Caddyfile that reverse proxies public HTTPS traffic to the local Spring Boot service on `127.0.0.1:8080`. The Spring Boot app remains on port `8080`, but public direct access to `8080` is removed.

**Tech Stack:** Terraform, AWS EC2 security groups, Amazon Linux 2023 user data, Caddy, systemd, Spring Boot.

---

### Task 1: Track Execution State

**Files:**
- Create: `checklist.md`
- Create: `context-notes.md`

- [ ] **Step 1: Create a task checklist**

Create `checklist.md` with checkboxes for planning, Terraform edits, documentation edits, verification, and commit.

- [ ] **Step 2: Create context notes**

Create `context-notes.md` with the decision that Terraform owns security group ingress and public outputs, while Caddy reverse proxy config is placed in EC2 bootstrap for reproducible replacement instances.

### Task 2: Change Public Network Shape

**Files:**
- Modify: `variables.tf`
- Modify: `security_group.tf`
- Modify: `environments/prod-saynow.tfvars.example`

- [ ] **Step 1: Replace public app port allow-list with HTTP/HTTPS allow-list**

Change `variables.tf` so backend public traffic has separate `http_allowed_cidr_blocks` and `https_allowed_cidr_blocks`, both defaulting to `["0.0.0.0/0"]`. Keep `app_allowed_cidr_blocks` because the AI backend still uses it for direct `app_port` access.

- [ ] **Step 2: Update backend security group ingress**

Change `security_group.tf` to allow TCP `80` and `443` from the new CIDR variables, and remove direct public ingress to `var.app_port`.

- [ ] **Step 3: Update the example production tfvars**

Change `environments/prod-saynow.tfvars.example` to keep `app_allowed_cidr_blocks` for the AI backend and add the two new backend HTTP/HTTPS CIDR variables.

### Task 3: Bootstrap Caddy Reverse Proxy

**Files:**
- Modify: `user_data.sh.tftpl`
- Modify: `main.tf`

- [ ] **Step 1: Pass backend domain into user data**

Add `backend_domain_name = var.backend_domain_name` to the `templatefile` call in `main.tf`.

- [ ] **Step 2: Install and configure Caddy**

Update `user_data.sh.tftpl` to install Caddy on Amazon Linux 2023, write `/etc/caddy/Caddyfile`, and enable the `caddy` service. The Caddyfile should reverse proxy `${backend_domain_name}` to `127.0.0.1:${app_port}`.

### Task 4: Publish HTTPS Outputs And Docs

**Files:**
- Modify: `variables.tf`
- Modify: `outputs.tf`
- Modify: `README.md`
- Modify: `docs/backend-deploy-github-actions.md`

- [ ] **Step 1: Add the backend domain variable**

Add `backend_domain_name` with default `saynow.p-e.kr`.

- [ ] **Step 2: Update public URL outputs**

Change `backend_app_url` to `https://${var.backend_domain_name}` and add a direct local service note only in documentation, not as a public output.

- [ ] **Step 3: Document HTTPS operations**

Document that DNS must point to the backend Elastic IP, security groups expose only 80/443 for public app traffic, Caddy terminates TLS, and `terraform apply` is required for AWS security group changes.

### Task 5: Verify And Commit

**Files:**
- All changed files.

- [ ] **Step 1: Format Terraform**

Run `terraform fmt -recursive`.

- [ ] **Step 2: Validate Terraform**

Run `AWS_PROFILE=prod-saynow terraform validate`.

- [ ] **Step 3: Review the Terraform plan**

Run `AWS_PROFILE=prod-saynow terraform plan -var-file=environments/prod-saynow.tfvars`.
Expected changes should be limited to backend security group ingress, EC2 user data drift replacement/update behavior, and output values. Do not run `terraform apply` without explicit user confirmation.

- [ ] **Step 4: Check diff and status**

Run `git diff` and `git status --short`.

- [ ] **Step 5: Commit**

Commit with a single logical message for the HTTPS/Caddy infrastructure change.
