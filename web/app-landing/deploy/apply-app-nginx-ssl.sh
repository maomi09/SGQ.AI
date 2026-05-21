#!/bin/bash
# Apply nginx + existing Let's Encrypt cert for app.sagp-qp.com
# Run on EC2: sudo bash apply-app-nginx-ssl.sh

set -euo pipefail

DOMAIN="app.sagp-qp.com"
WEB_ROOT="/var/www/sgq-app-landing"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"

if [ ! -f "$CERT_DIR/fullchain.pem" ]; then
  echo "ERROR: Certificate not found at $CERT_DIR"
  echo "Run first: sudo bash fix-app-ssl.sh your-email@example.com"
  exit 1
fi

if [ ! -f "$WEB_ROOT/index.html" ]; then
  echo "WARNING: $WEB_ROOT/index.html missing"
fi

echo "==> Installing nginx site config"
sudo cp "$SCRIPT_DIR/nginx-app-https.conf" /etc/nginx/sites-available/sgq-app-landing
sudo ln -sf /etc/nginx/sites-available/sgq-app-landing /etc/nginx/sites-enabled/sgq-app-landing

echo "==> Test and reload nginx"
sudo nginx -t
sudo systemctl reload nginx

echo ""
echo "OK: https://$DOMAIN"
echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null \
  | openssl x509 -noout -subject 2>/dev/null || true
