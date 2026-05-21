#!/bin/bash
# Usage: sudo bash install-on-ec2.sh app.sagp-qp.com

set -euo pipefail

DOMAIN="${1:-app.sagp-qp.com}"
WEB_ROOT="/var/www/sgq-app-landing"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Domain: $DOMAIN"
echo "==> Web root: $WEB_ROOT"

sudo mkdir -p "$WEB_ROOT"
sudo chown -R "$USER:$USER" "$WEB_ROOT" 2>/dev/null || true

if [ ! -f "$WEB_ROOT/index.html" ]; then
  echo "Warning: $WEB_ROOT/index.html missing. Run deploy-app-domain.ps1 from Windows first."
fi

sudo cp "$SCRIPT_DIR/nginx-app.sagp-qp.com.conf" /etc/nginx/sites-available/sgq-app-landing
sudo sed -i "s/app.sagp-qp.com/$DOMAIN/g" /etc/nginx/sites-available/sgq-app-landing
sudo ln -sf /etc/nginx/sites-available/sgq-app-landing /etc/nginx/sites-enabled/sgq-app-landing
sudo nginx -t
sudo systemctl reload nginx

if command -v certbot >/dev/null 2>&1; then
  echo "==> HTTPS: run on EC2 with a real email (admin@$DOMAIN often fails):"
  echo "    sudo bash fix-app-ssl.sh your-email@example.com"
else
  echo "Install certbot: sudo apt install -y certbot python3-certbot-nginx"
fi

echo ""
echo "Open: https://$DOMAIN"
echo "Edit store links in config.js on server or redeploy from Windows."
