#!/bin/bash
# 在 EC2 上執行：把教師匯出網站掛到 https://api.sagp-qp.com/teacher-export/
# 用法：sudo bash install-subpath-on-ec2.sh

set -euo pipefail

WEB_ROOT="/var/www/sgq-teacher-export"
SNIPPET_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/nginx-teacher-export-subpath.snippet"
SNIPPET_DST="/etc/nginx/snippets/sgq-teacher-export.conf"
INCLUDE_LINE='include /etc/nginx/snippets/sgq-teacher-export.conf;'

echo "==> 網站目錄: $WEB_ROOT"
sudo mkdir -p "$WEB_ROOT"
if [ ! -f "$WEB_ROOT/index.html" ]; then
  echo "錯誤: 找不到 $WEB_ROOT/index.html"
  echo "請先在 Windows 執行 deploy-aws.ps1 上傳檔案"
  exit 1
fi

echo "==> 安裝 Nginx snippet"
sudo cp "$SNIPPET_SRC" "$SNIPPET_DST"

NGINX_SITE=""
for candidate in /etc/nginx/sites-available/sgq-backend /etc/nginx/sites-available/default; do
  if [ -f "$candidate" ] && grep -q "api.sagp-qp.com\|proxy_pass" "$candidate" 2>/dev/null; then
    NGINX_SITE="$candidate"
    break
  fi
done

if [ -z "$NGINX_SITE" ]; then
  NGINX_SITE=$(grep -rl "server_name.*api" /etc/nginx/sites-available/ 2>/dev/null | head -1 || true)
fi

if [ -z "$NGINX_SITE" ]; then
  echo ""
  echo "找不到 api 的 Nginx 設定檔。請手動編輯 HTTPS 的 server 區塊，在 location / 之前加入："
  echo "  $INCLUDE_LINE"
  echo "snippet 已在: $SNIPPET_DST"
  exit 1
fi

echo "==> 設定檔: $NGINX_SITE"

if ! sudo grep -qF "$INCLUDE_LINE" "$NGINX_SITE"; then
  sudo sed -i "/location \//i\\    $INCLUDE_LINE" "$NGINX_SITE" || {
    echo "自動插入失敗，請手動在 location / 前加入: $INCLUDE_LINE"
    exit 1
  }
  echo "已加入 include"
else
  echo "include 已存在，略過"
fi

sudo nginx -t
sudo systemctl reload nginx

echo ""
echo "完成。請開啟: https://api.sagp-qp.com/teacher-export/"
echo "Supabase Site URL 請設為: https://api.sagp-qp.com/teacher-export/"
