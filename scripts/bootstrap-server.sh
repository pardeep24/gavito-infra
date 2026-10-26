#!/usr/bin/env bash
# One-time setup of a fresh Ubuntu or Debian server for ./gavito. Run as root:
#   sudo ./scripts/bootstrap-server.sh
# Installs Docker and git, and opens the web ports when a firewall is already on. Safe to re-run.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }
. /etc/os-release
case "${ID:-}" in ubuntu | debian) ;; *) echo "This script supports Ubuntu and Debian." >&2; exit 1 ;; esac

apt-get update -q
apt-get install -y -q ca-certificates curl git openssl rsync
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -q
  apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker

# Never switches a firewall on (that could cut other traffic); only opens the web ports if one is.
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q '^Status: active'; then
  ufw allow 80/tcp >/dev/null
  ufw allow 443/tcp >/dev/null
  ufw allow 443/udp >/dev/null
fi

# The user deploys run as, with Docker access.
id deploy >/dev/null 2>&1 || useradd --create-home --shell /bin/bash deploy
usermod -aG docker deploy

echo "Done. Next: clone gavito-infra to /opt/gavito (owned by deploy), fill in env/, then ./gavito up"
