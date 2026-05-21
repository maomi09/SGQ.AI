# AWS 部署指南（教師題目匯出）

使用與後端相同的 **`api.sagp-qp.com`**（EC2 IP：`3.80.19.9`），網址為：

**https://api.sagp-qp.com/teacher-export/**

不需另外申請 `export.sagp-qp.com` 或改 DNS。

---

## 你需要準備

1. AWS EC2 的 **`.pem` 金鑰**（建立實例時下載的那個）
2. 能 SSH 連線（本機已安裝 OpenSSH，Windows 通常內建）

---

## 一鍵部署（3 步）

### 1. 本機預覽（選用）

雙擊 `本機預覽.bat`，確認畫面正常。

### 2. 執行部署腳本

**建議：雙擊 `run-aws-deploy.bat`**（腳本訊息為英文，避免 CMD 亂碼）

或在 PowerShell：

```powershell
cd C:\Users\maola\Downloads\0521\SGQ.AI\web\teacher-export
powershell -ExecutionPolicy Bypass -File .\deploy-aws.ps1
```

若 CMD 中文變亂碼，見 [CMD中文亂碼修正.md](./CMD中文亂碼修正.md)。

第一次會問：

- EC2 IP（直接 Enter 用預設 `3.80.19.9`）
- `.pem` 金鑰路徑（例如 `C:\Users\maola\Downloads\my-key.pem`）

腳本會自動：

- 上傳網站檔到 `/var/www/sgq-teacher-export`
- 在 Nginx 加入 `/teacher-export/` 路徑
- 重新載入 Nginx

### 3. Supabase 設定（必做）

1. https://supabase.com/dashboard → 你的專案  
2. **Authentication** → **URL Configuration**  
3. 設定：

| 欄位 | 值 |
|------|-----|
| Site URL | `https://api.sagp-qp.com/teacher-export/` |
| Redirect URLs | `https://api.sagp-qp.com/teacher-export/` |

4. **Save**

---

## 驗證

瀏覽器開啟：**https://api.sagp-qp.com/teacher-export/**

- 應看到登入頁  
- 用教師帳號登入 → 選班級 / 單元 → 下載 Excel  

把網址寫進 `給老師的說明.txt` 傳給老師即可。

---

## 常見錯誤

### `Permission denied (publickey)`

- `.pem` 路徑錯誤，或使用者名稱應為 `ubuntu`（Amazon Linux 可能是 `ec2-user`）

```powershell
ssh -i "你的.pem" ubuntu@3.80.19.9
```

能連上再跑 `deploy-aws.ps1`。

### `nginx: configuration file ... test failed`

SSH 進伺服器手動檢查：

```bash
sudo nginx -t
sudo nano /etc/nginx/sites-available/sgq-backend
```

在 **`location /`** 那一行的**上方**加入：

```nginx
    include /etc/nginx/snippets/sgq-teacher-export.conf;
```

儲存後：

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### 登入失敗

- 確認 Supabase Site URL 已改成 `https://api.sagp-qp.com/teacher-export/`
- 教師帳號 `user_metadata.role` 為 `teacher`

### 更新網站內容

改完 `index.html` / `app.js` 後，再執行一次：

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy-aws.ps1
```

---

## 進階：獨立子網域 export.sagp-qp.com

若一定要用 `https://export.sagp-qp.com`：

1. DNS 新增 **A 記錄**：`export` → `3.80.19.9`  
2. 使用 `deploy/upload-windows.ps1` + `deploy/install-on-ec2.sh`  
3. Supabase URL 改為 `https://export.sagp-qp.com`  

一般情況建議用子路徑即可，較省事。

---

## EC2 安全群

確認入站規則已開放：

- **443**（HTTPS）
- **22**（SSH，僅你的 IP 較安全）

後端 API 與此靜態頁共用同一安全群。
