// 백엔드 EC2의 Caddy reverse proxy 설정을 SSM으로 적용한다.
locals {
  backend_caddy_commands = [
    "set -euo pipefail",
    "dnf install -y tar gzip",
    <<-EOC
CADDY_VERSION=2.11.2
CADDY_ARCHIVE="caddy_$${CADDY_VERSION}_linux_amd64.tar.gz"
CADDY_DOWNLOAD_URL="https://github.com/caddyserver/caddy/releases/download/v$${CADDY_VERSION}"
CADDY_TMP_DIR="$(mktemp -d)"
curl -fsSLo "$${CADDY_TMP_DIR}/$${CADDY_ARCHIVE}" "$${CADDY_DOWNLOAD_URL}/$${CADDY_ARCHIVE}"
curl -fsSLo "$${CADDY_TMP_DIR}/caddy_checksums.txt" "$${CADDY_DOWNLOAD_URL}/caddy_$${CADDY_VERSION}_checksums.txt"
(
  cd "$${CADDY_TMP_DIR}"
  sha512sum --ignore-missing -c caddy_checksums.txt
  tar -xzf "$${CADDY_ARCHIVE}" caddy
  install -o root -g root -m 0755 caddy /usr/bin/caddy
)
rm -rf "$${CADDY_TMP_DIR}"
EOC
    ,
    "id caddy >/dev/null 2>&1 || useradd --system --home-dir /var/lib/caddy --shell /sbin/nologin caddy",
    "mkdir -p /etc/caddy /var/lib/caddy /var/log/caddy",
    "chown caddy:caddy /var/lib/caddy /var/log/caddy",
    "chmod 755 /etc/caddy /var/lib/caddy /var/log/caddy",
    <<-EOC
cat >/etc/caddy/Caddyfile <<'CADDY'
${var.backend_domain_name} {
	reverse_proxy 127.0.0.1:${var.app_port}
}
CADDY
EOC
    ,
    "chown root:caddy /etc/caddy/Caddyfile",
    "chmod 640 /etc/caddy/Caddyfile",
    <<-EOC
cat >/etc/systemd/system/caddy.service <<'CADDY_SERVICE'
[Unit]
Description=Caddy web server
Documentation=https://caddyserver.com/docs/
After=network-online.target
Wants=network-online.target

[Service]
User=caddy
Group=caddy
Environment=XDG_DATA_HOME=/var/lib/caddy
Environment=XDG_CONFIG_HOME=/etc/caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
Restart=on-failure
RestartPreventExitStatus=1
TimeoutStopSec=5s
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target
CADDY_SERVICE
EOC
    ,
    "systemctl daemon-reload",
    "systemctl enable --now caddy",
    "systemctl reload caddy",
  ]
}

resource "aws_ssm_document" "backend_caddy" {
  name            = "${local.name_prefix}-backend-caddy"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Configure Caddy reverse proxy for the Saynow backend."
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "configureCaddy"
        inputs = {
          runCommand = local.backend_caddy_commands
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-backend-caddy"
  }
}

resource "aws_ssm_association" "backend_caddy" {
  name = aws_ssm_document.backend_caddy.name

  targets {
    key    = "tag:Name"
    values = ["${local.name_prefix}-backend"]
  }
}
