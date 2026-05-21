#!/bin/bash
# Fix HTTPS for export.sagp-qp.com on EC2
# Usage: sudo bash fix-export-ssl.sh your-real-email@example.com

set -euo pipefail

DOMAIN="export.sagp-qp.com"
EMAIL="${1:-}"

if [ -z "$EMAIL" ] || [[ "$EMAIL" != *"@"* ]]; then
  echo "Usage: sudo bash fix-export-ssl.sh your-email@example.com"
  echo "Example: sudo bash fix-export-ssl.sh teacher@school.edu.tw"
  exit 1
fi

echo "==> Checking DNS for $DOMAIN"
getent hosts "$DOMAIN" || true

echo "==> Nginx sites for $DOMAIN"
sudo grep -r "server_name.*$DOMAIN" /etc/nginx/sites-enabled/ /etc/nginx/sites-available/ 2>/dev/null || {
  echo "ERROR: No nginx config for $DOMAIN. Run install-on-ec2.sh first."
  exit 1
}

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
