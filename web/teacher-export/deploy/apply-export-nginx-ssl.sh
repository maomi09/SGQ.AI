#!/bin/bash
# Apply nginx + existing Let's Encrypt cert for export.sagp-qp.com
# Run on EC2: sudo bash apply-export-nginx-ssl.sh

set -euo pipefail

DOMAIN="export.sagp-qp.com"
WEB_ROOT="/var/www/sgq-teacher-export"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"

if [ ! -f "$CERT_DIR/fullchain.pem" ]; then
  echo "ERROR: Certificate not found at $CERT_DIR"
  echo "Run first: sudo certbot certonly --nginx -d $DOMAIN"
  echo "  or: sudo certbot --nginx -d $DOMAIN"
  exit 1
fi

if [ ! -f "$WEB_ROOT/index.html" ]; then
  echo "WARNING: $WEB_ROOT/index.html missing"
fi

echo "==> Installing nginx site config"
sudo cp "$SCRIPT_DIR/nginx-export-https.conf" /etc/nginx/sites-available/sgq-teacher-export
sudo ln -sf /etc/nginx/sites-available/sgq-teacher-export /etc/nginx/sites-enabled/sgq-teacher-export

# Optional: remove default site if it steals export traffic on 443
if [ -f /etc/nginx/sites-enabled/default ]; then
  echo "==> Disabling default site (optional)"
  sudo rm -f /etc/nginx/sites-enabled/default
fi

echo "==> Test and reload nginx"
sudo nginx -t
sudo systemctl reload nginx

echo ""
echo "OK: https://$DOMAIN"
echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null \
  | openssl x509 -noout -subject 2>/dev/null || true
