#!/bin/bash
# Fix HTTPS for app.sagp-qp.com on EC2
# Usage: sudo bash fix-app-ssl.sh your-real-email@example.com

set -euo pipefail

DOMAIN="app.sagp-qp.com"
WEB_ROOT="/var/www/sgq-app-landing"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMAIL="${1:-}"

if [ -z "$EMAIL" ] || [[ "$EMAIL" != *"@"* ]]; then
  echo "Usage: sudo bash fix-app-ssl.sh your-email@example.com"
  echo "Example: sudo bash fix-app-ssl.sh sgqaiapp@gmail.com"
  exit 1
fi

echo "==> Checking DNS for $DOMAIN"
getent hosts "$DOMAIN" || true

echo "==> Ensure HTTP site exists"
if [ ! -f /etc/nginx/sites-available/sgq-app-landing ]; then
  sudo cp "$SCRIPT_DIR/nginx-app.sagp-qp.com.conf" /etc/nginx/sites-available/sgq-app-landing
fi
sudo ln -sf /etc/nginx/sites-available/sgq-app-landing /etc/nginx/sites-enabled/sgq-app-landing

if [ ! -f "$WEB_ROOT/index.html" ]; then
  echo "WARNING: $WEB_ROOT/index.html missing. Deploy from Windows first."
fi

echo "==> Test nginx (HTTP)"
sudo nginx -t
sudo systemctl reload nginx

echo "==> Current certificates"
sudo certbot certificates 2>/dev/null || true

echo "==> Requesting / renewing certificate for $DOMAIN"
sudo certbot --nginx -d "$DOMAIN" \
  --non-interactive \
  --agree-tos \
  -m "$EMAIL" \
  --redirect

echo "==> Test nginx"
sudo nginx -t
sudo systemctl reload nginx

echo ""
echo "==> Certificate served on 443 (should mention $DOMAIN):"
echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null \
  | openssl x509 -noout -subject 2>/dev/null || echo "(openssl check failed - try browser again)"

echo ""
echo "Done. Open https://$DOMAIN in browser."
echo "If Chrome still blocks (HSTS), see SSL憑證錯誤排除.md"
