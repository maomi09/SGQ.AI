#!/bin/bash
# 在 EC2（與 api.sagp-qp.com 同一台）執行，設定 Nginx 與 HTTPS
# 用法：sudo bash install-on-ec2.sh export.sagp-qp.com

set -euo pipefail

DOMAIN="${1:-export.sagp-qp.com}"
WEB_ROOT="/var/www/sgq-teacher-export"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 網域: $DOMAIN"
echo "==> 網站目錄: $WEB_ROOT"

sudo mkdir -p "$WEB_ROOT"
sudo chown -R "$USER:$USER" "$WEB_ROOT" 2>/dev/null || true

if [ ! -f "$WEB_ROOT/index.html" ]; then
  echo "警告: $WEB_ROOT/index.html 不存在。請先從 Windows 執行 upload-windows.ps1"
fi

echo "==> 安裝 Nginx 設定"
sudo cp "$SCRIPT_DIR/nginx-export.sagp-qp.com.conf" /etc/nginx/sites-available/sgq-teacher-export
sudo sed -i "s/export.sagp-qp.com/$DOMAIN/g" /etc/nginx/sites-available/sgq-teacher-export
sudo ln -sf /etc/nginx/sites-available/sgq-teacher-export /etc/nginx/sites-enabled/sgq-teacher-export
sudo nginx -t
sudo systemctl reload nginx

echo "==> 申請 HTTPS（Let's Encrypt）"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"
if command -v certbot >/dev/null 2>&1; then
  if [ -n "$CERTBOT_EMAIL" ]; then
    sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos \
      -m "$CERTBOT_EMAIL" --redirect || true
  else
    echo "請手動申請憑證（需真實 Email，不可用 admin@網域）："
    echo "  sudo certbot --nginx -d $DOMAIN"
    echo "或: sudo bash fix-export-ssl.sh your-email@example.com"
  fi
else
  echo "未安裝 certbot: sudo apt install -y certbot python3-certbot-nginx"
fi

echo ""
echo "完成。請在瀏覽器開啟: https://$DOMAIN"
echo "並在 Supabase 後台加入此網址（見 DEPLOY_完整教學.md 第三節）"
