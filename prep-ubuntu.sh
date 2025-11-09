#!/usr/bin/env bash
set -euo pipefail

# Ubuntu prep script: install Docker, Minikube, Certbot, and fetch TLS certs.
#
# Usage:
#   CERTBOT_DOMAIN=example.com CERTBOT_EMAIL=admin@example.com ./prep-ubuntu.sh
#
# Notes:
# - Certbot standalone needs ports 80 and 443 free on this machine.
# - Certificates will be copied into ./certs/ (relative to this script).

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  SUDO=sudo
else
  SUDO=
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CERTS_DIR="$SCRIPT_DIR/certs"

echo "[1/5] Updating apt index and installing prerequisites..."
$SUDO apt-get update -y
$SUDO apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common

echo "[2/5] Installing Docker Engine..."
if ! command -v docker >/dev/null 2>&1; then
  # Add Docker’s official GPG key
  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg

  # Add the repository
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

  $SUDO apt-get update -y
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  $SUDO systemctl enable --now docker
  # Add current user to docker group (effective next login)
  if getent group docker >/dev/null; then
    $SUDO usermod -aG docker "${SUDO_USER:-$USER}"
  fi
else
  echo "Docker already installed; skipping."
fi

echo "[3/5] Installing Minikube..."
if ! command -v minikube >/dev/null 2>&1; then
  curl -Lo /tmp/minikube-linux-amd64 https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  $SUDO install /tmp/minikube-linux-amd64 /usr/local/bin/minikube
  rm -f /tmp/minikube-linux-amd64
else
  echo "Minikube already installed; skipping."
fi

echo "[4/5] Installing Certbot..."
if ! command -v certbot >/dev/null 2>&1; then
  if command -v snap >/dev/null 2>&1; then
    $SUDO snap install core
    $SUDO snap refresh core
    $SUDO snap install --classic certbot
    $SUDO ln -sf /snap/bin/certbot /usr/bin/certbot
  else
    # Fallback to apt if snapd is unavailable
    $SUDO apt-get install -y certbot
  fi
else
  echo "Certbot already installed; skipping."
fi

echo "[5/5] Obtaining TLS certificate via Certbot standalone..."
DOMAIN=${CERTBOT_DOMAIN:-}
EMAIL=${CERTBOT_EMAIL:-}
if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
  echo "CERTBOT_DOMAIN and CERTBOT_EMAIL must be set."
  echo "Example: CERTBOT_DOMAIN=example.com CERTBOT_EMAIL=admin@example.com $0"
  exit 1
fi

echo "Ensuring ports 80 and 443 are free for standalone verification..."
if ss -tulpn 2>/dev/null | grep -E ':(80|443)\s' >/dev/null 2>&1; then
  echo "Error: A service is already listening on port 80 or 443. Stop it before running Certbot --standalone."
  exit 1
fi

set -x
$SUDO certbot certonly --standalone -d "$DOMAIN" --agree-tos -m "$EMAIL" --non-interactive
set +x

LIVE_DIR="/etc/letsencrypt/live/$DOMAIN"
if [[ ! -d "$LIVE_DIR" ]]; then
  echo "Expected certs not found in $LIVE_DIR"
  exit 1
fi

mkdir -p "$CERTS_DIR"
cp -f "$LIVE_DIR/fullchain.pem" "$CERTS_DIR/fullchain.pem"
cp -f "$LIVE_DIR/privkey.pem" "$CERTS_DIR/privkey.pem"

echo "Done. Certificates copied to: $CERTS_DIR"
echo "Next: configure nginx to use $CERTS_DIR/fullchain.pem and $CERTS_DIR/privkey.pem"
