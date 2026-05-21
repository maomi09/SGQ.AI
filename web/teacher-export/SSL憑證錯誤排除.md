# export.sagp-qp.com 憑證錯誤排除

Chrome 訊息：「傳回了異常且錯誤的憑證」+ HSTS，代表 **HTTPS 憑證與網域名稱不符**，或 **尚未為 export 申請憑證**，卻用 `https://` 開啟。

DNS 正常時（`export.sagp-qp.com` → `3.80.19.9`），請在 **EC2 上**依下列步驟修復。

---

## 原因說明（簡短）

同一台 EC2 上有多個網域（`api`、`export`、`app`）。若 **只有 api 有 SSL**，瀏覽器連 `https://export.sagp-qp.com` 時可能拿到 **api 的憑證** → Chrome 報錯。

或當初 `certbot` 自動申請失敗（例如用了無效的 `admin@export.sagp-qp.com` 信箱）。

---

## 修復步驟（約 5 分鐘）

### 1. SSH 連線

```powershell
ssh -i "C:\Users\maola\Downloads\sgqai_app.pem" ubuntu@3.80.19.9
```

### 2. 上傳並執行修復腳本（從 Windows 另開 PowerShell）

```powershell
cd C:\Users\maola\Downloads\0521\SGQ.AI\web\teacher-export\deploy
scp -i "C:\Users\maola\Downloads\sgqai_app.pem" fix-export-ssl.sh ubuntu@3.80.19.9:/tmp/
```

在 **SSH 視窗**執行（把 Email 改成你的真實信箱）：

```bash
chmod +x /tmp/fix-export-ssl.sh
sudo bash /tmp/fix-export-ssl.sh 你的信箱@example.com
```

### 憑證已申請但顯示「Could not install certificate」

代表憑證在 `/etc/letsencrypt/live/export.sagp-qp.com/`，但 **Nginx 沒有 export 的 server 區塊**。

**做法 A（推薦）** — 上傳並執行：

```powershell
# Windows
scp -i "C:\Users\maola\Downloads\sgqai_app.pem" "C:\Users\maola\Downloads\0521\SGQ.AI\web\teacher-export\deploy\apply-export-nginx-ssl.sh" ubuntu@3.80.19.9:/tmp/
scp -i "C:\Users\maola\Downloads\sgqai_app.pem" "C:\Users\maola\Downloads\0521\SGQ.AI\web\teacher-export\deploy\nginx-export-https.conf" ubuntu@3.80.19.9:/tmp/sgq-teacher-export-deploy/
```

```bash
# EC2（兩個 conf 需在 deploy 目錄，或改路徑）
sudo bash /tmp/apply-export-nginx-ssl.sh
```

**做法 B** — 手動：

```bash
sudo certbot install --cert-name export.sagp-qp.com
```

若仍失敗，先建立 HTTP 站台再 install：

```bash
sudo cp /tmp/nginx-export.sagp-qp.com.conf /etc/nginx/sites-available/sgq-teacher-export
sudo ln -sf /etc/nginx/sites-available/sgq-teacher-export /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot install --cert-name export.sagp-qp.com
```

或直接用完整 HTTPS 設定檔（見 `deploy/nginx-export-https.conf`）。

### 3. 確認 Nginx

```bash
sudo nginx -t
sudo systemctl reload nginx
sudo certbot certificates
```

應看到 `export.sagp-qp.com` 的憑證。

### 4. 確認憑證主體（選用）

```bash
echo | openssl s_client -connect export.sagp-qp.com:443 -servername export.sagp-qp.com 2>/dev/null | openssl x509 -noout -subject
```

應包含 `export.sagp-qp.com` 或 Let's Encrypt 字樣。

### 5. 瀏覽器再試

開啟：**https://export.sagp-qp.com**

---

## 若仍被 HSTS 擋住

先前錯誤憑證可能已被 Chrome 記住。

1. Chrome 網址列輸入：`chrome://net-internals/#hsts`
2. **Delete domain security policies** → 輸入 `export.sagp-qp.com` → Delete
3. 關閉分頁，重新開啟 https://export.sagp-qp.com

或用 **無痕視窗** 測試。

---

## certbot 常見失敗

| 錯誤 | 處理 |
|------|------|
| DNS 未生效 | 等 `nslookup export.sagp-qp.com` 指向 3.80.19.9 |
| 80 埠被擋 | AWS 安全群開放 **80、443** |
| 信箱無效 | 用真實 Email，不要用 `admin@export.sagp-qp.com` |
| 已有錯誤憑證 | `sudo certbot delete --cert-name export.sagp-qp.com` 後重新申請 |

---

## 暫時只用 HTTP 測試（不建議長期）

僅供確認「網站檔案有上傳」：

**http://export.sagp-qp.com**（注意是 http）

若 HTTP 正常、HTTPS 失敗，幾乎可確定是憑證問題，照上方 certbot 修復即可。

---

## 修復後記得

Supabase **Site URL** 請用 **https**（不是 http）：

`https://export.sagp-qp.com`
