# app.sagp-qp.com 憑證錯誤排除

Chrome 訊息：「傳回了異常且錯誤的憑證」+ HSTS，代表 **HTTPS 憑證與網域名稱不符**，或 **尚未為 app 申請憑證**。

常見原因：EC2 上只有 `api`、`export` 的 SSL，連 `https://app.sagp-qp.com` 時 Nginx 誤用 **api 的憑證**。

---

## 修復步驟（約 5 分鐘）

### 1. SSH 連線

```powershell
ssh -i "C:\Users\maola\Downloads\sgqai_app.pem" ubuntu@3.80.19.9
```

### 2. 上傳修復腳本（Windows 另開 PowerShell）

```powershell
cd C:\Users\maola\Downloads\0521\SGQ.AI\web\app-landing\deploy
scp -i "C:\Users\maola\Downloads\sgqai_app.pem" fix-app-ssl.sh nginx-app.sagp-qp.com.conf nginx-app-https.conf apply-app-nginx-ssl.sh ubuntu@3.80.19.9:/tmp/sgq-app-landing-deploy/
```

### 3. 在 EC2 執行（Email 改成你的真實信箱）

```bash
chmod +x /tmp/sgq-app-landing-deploy/fix-app-ssl.sh
sudo bash /tmp/sgq-app-landing-deploy/fix-app-ssl.sh sgqaiapp@gmail.com
```

### 4. 確認

```bash
sudo certbot certificates
echo | openssl s_client -connect app.sagp-qp.com:443 -servername app.sagp-qp.com 2>/dev/null | openssl x509 -noout -subject
```

應看到 `app.sagp-qp.com`。

### 5. 瀏覽器

開啟：**https://app.sagp-qp.com**

---

## HSTS 仍擋住時

1. Chrome：`chrome://net-internals/#hsts`
2. **Delete domain security policies** → 輸入 `app.sagp-qp.com` → Delete
3. 關閉分頁後重開，或用**無痕視窗**測試

---

## 憑證已有但 Nginx 沒接上

```bash
sudo bash /tmp/sgq-app-landing-deploy/apply-app-nginx-ssl.sh
```

（腳本與 `nginx-app-https.conf` 須在同一目錄）

---

## certbot 常見失敗

| 錯誤 | 處理 |
|------|------|
| DNS 未生效 | `nslookup app.sagp-qp.com` 應為 `3.80.19.9` |
| 80、443 被擋 | AWS 安全群開放 **80、443** |
| 信箱無效 | 勿用 `admin@app.sagp-qp.com`，用真實 Gmail 等 |
| 站台未啟用 | 確認 `/etc/nginx/sites-enabled/sgq-app-landing` 存在 |

---

## 暫時用 HTTP 測檔案（不建議長期）

**http://app.sagp-qp.com** — 若 HTTP 正常、HTTPS 失敗，即為憑證問題。
