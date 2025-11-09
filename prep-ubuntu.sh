#!/usr/bin/env bash
set -euo pipefail

# Ubuntu prep script: warn if Docker/Minikube missing, install Certbot, fetch TLS certs.
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

echo "[1/3] Checking Docker and Minikube presence..."
if ! command -v docker >/dev/null 2>&1; then
  echo "Warning: Docker is not installed. Install Docker if you plan to run containers."
fi
if ! command -v minikube >/dev/null 2>&1; then
  echo "Warning: Minikube is not installed. Install Minikube if you plan to use Kubernetes locally."
fi

echo "[2/3] Installing Certbot if needed..."
if ! command -v certbot >/dev/null 2>&1; then
  if command -v snap >/dev/null 2>&1; then
    $SUDO snap install core
    $SUDO snap refresh core
    $SUDO snap install --classic certbot
    $SUDO ln -sf /snap/bin/certbot /usr/bin/certbot
  else
    # Fallback to apt if snapd is unavailable
    $SUDO apt-get update -y
    $SUDO apt-get install -y certbot
  fi
else
  echo "Certbot already installed; skipping."
fi

echo "[3/3] Obtaining TLS certificate via Certbot standalone..."
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
