#!/bin/bash
set -e

if [ -z "$REPO_URL" ]; then
  echo "REPO_URL is not set, exiting"
  exit 1
fi

if [ -d /var/www/html/.git ]; then
  cd /var/www/html && git pull
else
  git clone "$REPO_URL" /var/www/html
fi

nginx -s reload || nginx  # reload if running; start otherwise

exec "$@"
