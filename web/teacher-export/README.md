# SGQ 教師題目匯出（網頁版）

App 目前沒有內建 Excel 匯出；此靜態網頁供**教師**用瀏覽器登入後，從 Supabase 讀取題目並下載 Excel / CSV。

**從頭部署（推薦）：[從頭部署-export.sagp-qp.com.md](./從頭部署-export.sagp-qp.com.md)** — 雙擊 `run-export-domain.bat` → `https://export.sagp-qp.com`（不動後端 API）

其他方式：[DEPLOY_完整教學.md](./DEPLOY_完整教學.md)（含 Netlify）

資料權限與 App 相同（Supabase RLS + 教師 JWT），不需額外後端 API。

## 功能

- 教師 Email / 密碼登入（與 App 相同帳號）
- 依班級、課程單元、學生篩選
- 匯出欄位：課程單元、學生姓名、學號、班級、題型、題目、選項、正確答案、解析、階段、教師評語、建立/更新時間

## 本機預覽

在專案根目錄執行（需任一靜態伺服器，避免 `file://` 造成 CORS）：

```powershell
cd web\teacher-export
python -m http.server 8080
```

瀏覽器開啟：`http://localhost:8080`

## 部署方式（擇一）

### 1. 與現有網域同站（建議）

將 `web/teacher-export/` 整個資料夾放到 `https://你的網域/teacher-export/`，例如：

- `https://sagp-qp.com/teacher-export/`

### 2. AWS S3 + CloudFront 靜態網站

上傳 `index.html`、`app.js`、`styles.css`、`config.js` 到 S3 bucket，開啟靜態網站託管。

### 3. Netlify / Vercel

將 `web/teacher-export` 設為 publish directory，一鍵部署。

## 注意事項

1. **帳號角色**：登入帳號的 `user_metadata.role` 必須為 `teacher`（與 App 註冊教師相同）。
2. **HTTPS**：正式環境請使用 HTTPS；Supabase Auth 在部分瀏覽器會限制非安全來源。
3. **密碼重設**：與 App 相同，使用 Supabase / App 內忘記密碼流程。
4. **與 App 匯出 API**：`app/lib/services/supabase_service.dart` 內已有 `getQuestionExportRowsByTopic`，日後也可直接做進 App；網頁版邏輯與其對齊。

## 疑難排解

| 狀況 | 處理 |
|------|------|
| 登入失敗 | 確認信箱密碼、Supabase Auth 是否啟用 Email |
| 不是教師 | 在 Supabase Dashboard 檢查該使用者的 `raw_user_meta_data.role` |
| 匯出 0 筆 | 確認 RLS 政策 `Teachers can read all student questions` 已套用 |
| Excel 中文亂碼 | 請用「下載 Excel (.xlsx)」；CSV 已加 UTF-8 BOM |
