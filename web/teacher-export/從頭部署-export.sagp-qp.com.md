# 從頭部署教師匯出網站（https://export.sagp-qp.com）

給完全沒架過網站的人用的逐步教學。  
**不用重新部署 Python 後端**，App 的 `api.sagp-qp.com` 維持不變。

---

## 先搞懂三件事

| 名稱 | 網址 | 是什麼 |
|------|------|--------|
| 後端 API | `https://api.sagp-qp.com` | Python，給 App 用 → **這份教學不動它** |
| 教師匯出網站 | `https://export.sagp-qp.com` | 網頁，老師用瀏覽器匯出 Excel → **我們要架這個** |
| 資料庫登入 | Supabase | 網頁用教師帳密登入 → **要改一個設定** |

三台都在同一台 AWS EC2（IP：`3.80.19.9`）上可以共存。

---

## 準備清單（請先備齊）

- [ ] 電腦有 **PowerShell**（Windows 內建）
- [ ] 檔案 **`sgqai_app.pem`**（AWS SSH 金鑰，通常在「下載」資料夾）
- [ ] 能登入 **買 sagp-qp.com 網域的地方**（GoDaddy、Cloudflare、Route 53 等）
- [ ] 能登入 **Supabase** 後台
- [ ] 一組 **教師** 測試帳號（與 App 相同 Email / 密碼）

---

## 第 0 步：本機先看網站長怎樣（選用）

1. 進入資料夾：`SGQ.AI\web\teacher-export\`
2. 雙擊 **`本機預覽.bat`**
3. 瀏覽器開 **http://localhost:8080**
4. 看完按終端機 **Ctrl+C** 關閉

本機要登入的話，Supabase 還要多加 `http://localhost:8080`（見第 5 步）。

---

## 第 1 步：設定 DNS（網域指向你的伺服器）

1. 登入你管理 **sagp-qp.com** 的網站（不是 AWS 也可以，看當初網域買在哪）
2. 找到 **DNS 管理** / **DNS 記錄**
3. **新增一筆**：

| 類型 | 名稱 / Host | 值 / 指向 | TTL |
|------|-------------|-----------|-----|
| **A** | `export` | `3.80.19.9` | 預設即可 |

意思是：`export.sagp-qp.com` → 你的 EC2。

4. 儲存，等待 **5～30 分鐘**（有時更快）

5. 在 PowerShell 檢查是否生效：

```powershell
nslookup export.sagp-qp.com
```

應看到 `3.80.19.9`。若還沒有，等一會再試，**DNS 沒生效前 HTTPS 會失敗**。

---

## 第 2 步：確認 SSH 能連上 EC2

在 PowerShell 執行（路徑改成你的 `.pem`）：

```powershell
ssh -i "C:\Users\maola\Downloads\sgqai_app.pem" ubuntu@3.80.19.9
```

- 第一次問 `yes/no` → 輸入 **`yes`**
- 若出現 `ubuntu@...$` 命令列 → 成功
- 輸入 **`exit`** 離開

若失敗：

- 確認用的是 **`sgqai_app.pem`**（不是 `cacert.pem`）
- 到 AWS Console → EC2 → 安全群 → 確認 **22** 埠有開放

---

## 第 3 步：一鍵上傳網站並設定 Nginx（Windows）

1. 雙擊：

   **`run-export-domain.bat`**

   （在 `web\teacher-export\` 資料夾裡）

2. 若第一次執行：

   - **EC2 IP**：直接按 **Enter**（使用 `3.80.19.9`）
   - **.pem 路徑**：貼上  
     `C:\Users\maola\Downloads\sgqai_app.pem`

3. 若已有 `deploy\deploy-params.ps1`，會直接上傳，不再詢問。

4. 等腳本跑完，最後應看到 **`Done`** 和 **`Teacher URL: https://export.sagp-qp.com`**

腳本會自動：

- 上傳網頁檔（含 logo）到伺服器
- 設定 Nginx 給 `export.sagp-qp.com`
- 嘗試申請 HTTPS 憑證（Let's Encrypt）

### 若 HTTPS / certbot 失敗，或 Chrome 顯示「憑證錯誤」

見 **[SSL憑證錯誤排除.md](./SSL憑證錯誤排除.md)**。

快速修復（SSH 內，改用**真實信箱**）：

```bash
sudo certbot --nginx -d export.sagp-qp.com
```

或上傳 `deploy/fix-export-ssl.sh` 後：

```bash
sudo bash /tmp/fix-export-ssl.sh 你的信箱@example.com
```

---

## 第 4 步：瀏覽器測試網站

開啟：**https://export.sagp-qp.com**

- 應看到 SGQ logo 與登入畫面
- 若只有 http、或憑證錯誤 → 回到第 3 步處理 certbot

此時可能還**無法登入**，要做第 5 步。

---

## 第 5 步：Supabase 設定（登入必做）

1. 開啟 https://supabase.com/dashboard
2. 選你的專案（與 App 相同那個）
3. 左側 **Authentication** → **URL Configuration**
4. 設定：

| 欄位 | 填入 |
|------|------|
| **Site URL** | `https://export.sagp-qp.com` |
| **Redirect URLs** | 點 Add，加入 `https://export.sagp-qp.com` |

5. 按 **Save**

### 本機測試時額外加入（選用）

Redirect URLs 也可加：

- `http://localhost:8080`

---

## 第 6 步：用教師帳號完整測試

1. 開 **https://export.sagp-qp.com**
2. 教師 **Email / 密碼** 登入（與 App 相同）
3. 選 **班級**、**課程單元**（或選一位學生）
4. 按 **下載 Excel (.xlsx)**，確認檔案有資料

### 登入失敗時

| 訊息 | 處理 |
|------|------|
| 不是教師 | Supabase → Users → 該帳號 → User Metadata 要有 `"role": "teacher"` |
| 無法登入 / redirect | 確認 Site URL、Redirect URLs 已 Save |
| 匯出 0 筆 | 換有題目的課程單元或學生 |

---

## 第 7 步：給老師使用

把 `給老師的說明.txt` 裡的網址確認為：

**https://export.sagp-qp.com**

傳給老師即可。

---

## 之後只改網頁內容

改完 `index.html`、`app.js` 等後，再雙擊一次 **`run-export-domain.bat`** 就會覆蓋伺服器上的檔案。  
**不必**重啟後端、不必重上架 App。

---

## 流程總覽（一張表）

| 順序 | 做什麼 | 在哪做 |
|------|--------|--------|
| 1 | DNS A 記錄 `export` → `3.80.19.9` | 網域商後台 |
| 2 | `ssh` 測試連線 | 本機 PowerShell |
| 3 | `run-export-domain.bat` | 本機 Windows |
| 4 | 開 https://export.sagp-qp.com | 瀏覽器 |
| 5 | Supabase URL 設定 | Supabase 後台 |
| 6 | 教師登入 + 匯出測試 | 瀏覽器 |

---

## 常見問題

**Q：會影響 App 或 api.sagp-qp.com 嗎？**  
A：不會。只多一個靜態網站與 Nginx 設定，後端 Python 服務不變。

**Q：以前用 api.sagp-qp.com/teacher-export/ 還能用嗎？**  
A：若當初有裝子路徑，可能仍可用；正式建議改用 `https://export.sagp-qp.com`。

**Q：deploy-aws.ps1 和 deploy-export-domain.ps1 差別？**  
A：前者掛在 `api.../teacher-export/`；**你要的子網域請用 `run-export-domain.bat`**。

---

## 需要幫助時請提供

1. `nslookup export.sagp-qp.com` 結果  
2. `run-export-domain.bat` 完整錯誤文字  
3. 瀏覽器登入時的錯誤畫面或 F12 Console 訊息
