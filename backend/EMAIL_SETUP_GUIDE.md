# 郵件發送設定指南

## 方案 1：使用 Gmail SMTP（推薦，最簡單）

### 步驟 1：啟用 Gmail 應用程式密碼

1. 登入您的 Gmail 帳號
2. 前往 [Google 帳號設定](https://myaccount.google.com/)
3. 點擊「安全性」
4. 啟用「兩步驟驗證」（如果尚未啟用）
5. 在「應用程式密碼」區塊：
   - 選擇「郵件」和「其他（自訂名稱）」
   - 輸入名稱（例如：AI-APP）
   - 點擊「產生」
   - **複製生成的 16 位密碼**（只會顯示一次）

### 步驟 2：設定環境變數

在 `backend` 目錄下創建 `.env` 檔案（如果還沒有），並添加：

```env
SMTP_ENABLED=true
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_16_digit_app_password
SMTP_FROM_EMAIL=your_email@gmail.com
```

**重要**：使用應用程式密碼，不是您的 Gmail 登入密碼！

### 步驟 3：測試

1. 重啟後端服務：
   ```bash
   cd backend
   uvicorn main:app --reload
   ```

2. 在應用程式中發送驗證碼
3. 檢查您的電子郵件收件匣

## 方案 2：使用 Outlook/Hotmail SMTP

### 設定環境變數

```env
SMTP_ENABLED=true
SMTP_SERVER=smtp-mail.outlook.com
SMTP_PORT=587
SMTP_USERNAME=your_email@outlook.com
SMTP_PASSWORD=your_password
SMTP_FROM_EMAIL=your_email@outlook.com
```

## 方案 3：使用 SendGrid（適合生產環境）

### 步驟 1：註冊 SendGrid

1. 前往 [SendGrid](https://sendgrid.com/) 註冊帳號
2. 完成帳號驗證
3. 創建 API Key：
   - 前往 Settings > API Keys
   - 點擊 "Create API Key"
   - 選擇 "Full Access" 或 "Restricted Access"（選擇 Mail Send）
   - 複製 API Key（只會顯示一次）

### 步驟 2：設定環境變數

```env
SENDGRID_ENABLED=true
SENDGRID_API_KEY=your_sendgrid_api_key
SENDGRID_FROM_EMAIL=noreply@yourapp.com
```

### 步驟 3：安裝 SendGrid 套件

```bash
pip install sendgrid
```

### 步驟 4：驗證發送者郵件

在 SendGrid Dashboard 中驗證您的發送者郵件地址。

## 方案 4：使用其他 SMTP 服務

### 常見 SMTP 設定

**QQ 郵箱**：
```env
SMTP_SERVER=smtp.qq.com
SMTP_PORT=587
```

**163 郵箱**：
```env
SMTP_SERVER=smtp.163.com
SMTP_PORT=25
```

**企業郵箱**：
請聯繫您的 IT 部門獲取 SMTP 設定。

## 故障排除

### Gmail 發送失敗

1. **確認已啟用兩步驟驗證**
2. **確認使用應用程式密碼**（不是登入密碼）
3. **檢查防火牆設定**（確保允許連接 smtp.gmail.com:587）

### 連接被拒絕

- 檢查 SMTP_SERVER 和 SMTP_PORT 是否正確
- 確認防火牆允許連接
- 某些網路可能封鎖 SMTP 端口

### 認證失敗

- 確認 SMTP_USERNAME 和 SMTP_PASSWORD 正確
- Gmail 必須使用應用程式密碼
- 檢查帳號是否啟用「允許安全性較低的應用程式存取」（已棄用，應使用應用程式密碼）

## 開發模式

如果不想設定郵件服務，可以保持 `SMTP_ENABLED=false`，驗證碼會：
- 顯示在後端終端中
- 顯示在應用程式的 SnackBar 中

## 安全建議

1. **永遠不要將 `.env` 檔案提交到 Git**
2. **使用應用程式密碼**（Gmail）而不是登入密碼
3. **生產環境使用 SendGrid 或其他專業郵件服務**
4. **限制 API Key 權限**（SendGrid）

