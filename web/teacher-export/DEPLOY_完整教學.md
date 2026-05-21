# 教師題目匯出網站：完整上架教學（網域小白版）

你已經有網站檔案，只差「放到網路上」。下面兩種做法擇一即可。

| 方案 | 難度 | 多久能上線 | 網址範例 |
|------|------|----------|----------|
| **A. Netlify 拖曳上傳** | 最簡單 | 約 10 分鐘 | `https://隨機名稱.netlify.app` |
| **B. 自己的網域 sagp-qp.com** | 需 EC2 / DNS | 約 30–60 分鐘 | `https://export.sagp-qp.com` |

**不論哪種方案，都必須完成「第三節 Supabase 設定」，否則老師無法登入。**

---

## 上架前檢查清單（可列印）

- [ ] 本機預覽正常（雙擊 `本機預覽.bat`，開 `http://localhost:8080` 能看見登入頁）
- [ ] 已選方案 A 或 B 並完成對應步驟
- [ ] Supabase 已加入網站網址（第三節）
- [ ] 用教師帳號在正式網址登入並試匯出一次

---

## 第一節：本機先確認網站沒問題

1. 進入資料夾：`SGQ.AI\web\teacher-export\`
2. 雙擊 **`本機預覽.bat`**
3. 瀏覽器開啟：**http://localhost:8080**
4. 應看到「SGQ 教師題目匯出」登入畫面

若 Python 未安裝，可在 PowerShell 執行：

```powershell
cd 你的路徑\SGQ.AI\web\teacher-export
py -m http.server 8080
```

---

## 第二節 A：Netlify 上線（推薦，不用自己架伺服器）

### A-1. 註冊 Netlify

1. 開啟 https://www.netlify.com/
2. 用 Email 或 GitHub 註冊（免費方案即可）

### A-2. 上傳網站

1. 登入後點 **Add new site** → **Deploy manually**
2. 把整個資料夾 **`teacher-export`** 裡的檔案拖進虛線框  
   （需包含 `index.html`、`app.js`、`styles.css`、`config.js`）
3. 等待約 1 分鐘，狀態變 **Published**
4. 點進站點，複製網址，例如：`https://amazing-name-123456.netlify.app`

### A-3. 自訂網址（選用）

若你有 `sagp-qp.com` 且想在 Netlify 使用子網域：

1. Netlify 站點 → **Domain management** → **Add domain** → 輸入 `export.sagp-qp.com`
2. Netlify 會顯示要設定的 **DNS 記錄**（通常是 CNAME）
3. 到購買網域的地方（GoDaddy、Cloudflare、Route 53 等）新增該筆 DNS
4. 等待 5 分鐘～數小時生效

若暫時不做 DNS，老師直接使用 `https://xxx.netlify.app` 即可。

### A-4. 記下你的正式網址

後面 Supabase 要填入，例如：

`https://amazing-name-123456.netlify.app`

---

## 第二節 B：放在 AWS EC2（與 api.sagp-qp.com 同一台）

適合你已經會 SSH 進後端伺服器的情況。

### B-1. 查 EC2 公網 IP

1. 登入 AWS Console → EC2 → Instances
2. 選跑 `api.sagp-qp.com` 的那台
3. 複製 **Public IPv4 address**（例如 `3.15.xxx.xxx`）

### B-2. DNS 新增子網域

到管理 **sagp-qp.com** 的 DNS 後台（不一定是 AWS，看你當初買網域的地方）：

| 類型 | 名稱 / Host | 值 / 指向 |
|------|-------------|-----------|
| **A** | `export` | 你的 EC2 公網 IP |

儲存後，用 PowerShell 測試（過幾分鐘再試）：

```powershell
nslookup export.sagp-qp.com
```

應解析到同一個 IP。

### B-3. 設定上傳參數（Windows）

```powershell
cd 你的路徑\SGQ.AI\web\teacher-export\deploy
Copy-Item deploy-params.example.ps1 deploy-params.ps1
notepad deploy-params.ps1
```

填入：

- `Ec2UserAtHost`：例如 `ubuntu@3.15.xxx.xxx`
- `SshKeyPath`：你的 `.pem` 金鑰完整路徑
- `ExportDomain`：`export.sagp-qp.com`

### B-4. 上傳檔案

```powershell
powershell -ExecutionPolicy Bypass -File .\upload-windows.ps1
```

### B-5. SSH 進伺服器安裝 Nginx + HTTPS

```powershell
ssh -i "你的.pem路徑" ubuntu@你的EC2IP
```

在伺服器上：

```bash
cd ~
# 若 deploy 資料夾已隨專案在伺服器上：
sudo bash /path/to/SGQ.AI/web/teacher-export/deploy/install-on-ec2.sh export.sagp-qp.com
```

或手動：

```bash
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx
sudo cp nginx-export.sagp-qp.com.conf /etc/nginx/sites-available/sgq-teacher-export
sudo ln -sf /etc/nginx/sites-available/sgq-teacher-export /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d export.sagp-qp.com
```

### B-6. 正式網址

`https://export.sagp-qp.com`

---

## 第三節：Supabase 設定（必做，否則無法登入）

1. 開啟 https://supabase.com/dashboard  
2. 選專案 **iqmhqdkpultzyzurolwv**（與 App 相同）
3. 左側 **Authentication** → **URL Configuration**
4. 修改：

| 欄位 | 填入（改成你的實際網址） |
|------|-------------------------|
| **Site URL** | `https://你的網址/`（Netlify 或 export.sagp-qp.com，結尾可加可不加 `/`） |
| **Redirect URLs** | 同一個網址，點 Add URL 加入 |

範例（Netlify）：

```
https://amazing-name-123456.netlify.app
```

範例（自架）：

```
https://export.sagp-qp.com
```

5. 按 **Save**

### 確認教師帳號角色

**Authentication** → **Users** → 點教師帳號 → **User Metadata** 應有：

```json
"role": "teacher"
```

與 App 註冊時相同。若沒有，老師登入後會顯示「不是教師」。

---

## 第四節：交給老師的使用方式

把下面文字傳給老師即可：

---

**SGQ 題目匯出（網頁版）**

1. 用電腦瀏覽器開啟：（貼你的正式網址）
2. 使用與 **SGQ App 相同的教師 Email、密碼** 登入
3. 選班級、課程單元（或指定學生）
4. 按 **下載 Excel (.xlsx)**

---

## 第五節：常見問題

### 登入失敗 / Invalid login

- 確認信箱密碼與 App 相同
- 確認 Supabase **Site URL** 已改成正式網址並 Save

### 此帳號不是教師

- Supabase 該使用者的 `user_metadata.role` 必須是 `teacher`

### 匯出 0 筆

- 確認有選課程單元，或只選一位學生匯出全部題目
- 資料庫需有 RLS 政策允許教師讀取題目（專案內 `database/add_teacher_read_questions_policy.sql`）

### Netlify 可以，自架網域不行

- 檢查 DNS `export` 是否指向正確 IP
- 檢查 EC2 安全群是否開放 **80、443** 埠

### 只想改網址、不換主機

- 重新上傳：再執行一次 `upload-windows.ps1`（會覆蓋 html/js/css）

---

## 檔案說明

| 檔案 | 用途 |
|------|------|
| `index.html` / `app.js` / `styles.css` | 網站本體 |
| `config.js` | Supabase 連線（與 App 相同 anon key） |
| `deploy/upload-windows.ps1` | 上傳到 EC2 |
| `deploy/install-on-ec2.sh` | EC2 上設定 Nginx + HTTPS |
| `netlify.toml` | Netlify 部署設定 |

---

## 你需要提供給協助者的資訊（若請人代架）

1. 選方案 A 或 B  
2. EC2 公網 IP 與 SSH `.pem`（僅方案 B）  
3. sagp-qp.com 的 DNS 後台登入方式（僅方案 B 自訂網域）  
4. 一組可測試的教師帳號（勿公開密碼）

完成後把 **正式網址** 寫在 App 說明或傳給老師即可。
