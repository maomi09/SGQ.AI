# 註冊驗證碼功能配置指南

## 問題說明

如果遇到錯誤 `Signups not allowed for otp`，這表示 Supabase 不允許使用 OTP 進行註冊。

## 解決方案

### 方案 1：啟用 Supabase OTP 註冊（推薦）

1. 登入 [Supabase Dashboard](https://supabase.com/dashboard)
2. 前往 **Authentication** > **Providers**
3. 找到 **Email** 選項
4. 確認以下設定：
   - **Enable email provider** 已啟用
   - **Enable sign ups** 已啟用
   - **Enable email confirmations** 可以關閉（開發環境）或啟用（生產環境）

5. 如果仍然無法使用 OTP 註冊，可能需要：
   - 檢查 Supabase 計劃限制（免費版可能有 OTP 限制）
   - 升級到付費計劃

### 方案 2：使用後端 API（當前實現）

應用程式已實現後端 API 作為備選方案：

1. **啟動後端服務**：
   ```bash
   cd backend
   uvicorn main:app --reload
   ```

2. **後端 API 端點**：
   - `POST /api/send-verification-code` - 發送驗證碼
   - `POST /api/verify-code` - 驗證驗證碼

3. **工作流程**：
   - 應用程式會優先嘗試使用後端 API
   - 如果後端 API 不可用，會回退到 Supabase OTP
   - 如果兩者都失敗，會顯示錯誤訊息

4. **開發模式**：
   - 驗證碼會顯示在後端日誌中
   - 生產環境應整合專業郵件服務（SendGrid、Mailgun 等）

### 方案 3：整合專業郵件服務（生產環境推薦）

#### 使用 SendGrid

1. **安裝依賴**：
   ```bash
   pip install sendgrid
   ```

2. **修改 `backend/main.py`**：
   ```python
   from sendgrid import SendGridAPIClient
   from sendgrid.helpers.mail import Mail
   
   # 在 send_verification_code 函數中
   message = Mail(
       from_email='noreply@yourapp.com',
       to_emails=email,
       subject='註冊驗證碼',
       html_content=f'您的驗證碼是：<strong>{code}</strong>，10 分鐘內有效。'
   )
   sg = SendGridAPIClient(os.getenv('SENDGRID_API_KEY'))
   sg.send(message)
   ```

3. **設置環境變數**：
   ```bash
   export SENDGRID_API_KEY='your_sendgrid_api_key'
   ```

#### 使用 Mailgun

1. **安裝依賴**：
   ```bash
   pip install requests
   ```

2. **修改 `backend/main.py`**：
   ```python
   import requests
   
   # 在 send_verification_code 函數中
   requests.post(
       "https://api.mailgun.net/v3/your-domain.com/messages",
       auth=("api", os.getenv('MAILGUN_API_KEY')),
       data={
           "from": "noreply@your-domain.com",
           "to": email,
           "subject": "註冊驗證碼",
           "text": f"您的驗證碼是：{code}，10 分鐘內有效。"
       }
   )
   ```

## 當前實現說明

### 後端 API 實現

- **驗證碼存儲**：目前使用內存存儲（`verification_codes` 字典）
- **過期時間**：10 分鐘
- **驗證成功後**：延長 30 分鐘有效期

### 生產環境建議

1. **使用 Redis 或資料庫存儲驗證碼**：
   ```python
   # 使用 Redis
   import redis
   r = redis.Redis(host='localhost', port=6379, db=0)
   r.setex(f'verification:{email}', 600, code)  # 10 分鐘過期
   ```

2. **整合專業郵件服務**（SendGrid、Mailgun、AWS SES 等）

3. **設置環境變數**：
   - `BACKEND_URL` - 後端 API URL
   - `SENDGRID_API_KEY` 或 `MAILGUN_API_KEY` - 郵件服務 API 金鑰

## 測試步驟

### 測試後端 API

1. 啟動後端服務：
   ```bash
   cd backend
   uvicorn main:app --reload
   ```

2. 在應用程式中點擊「發送驗證碼」

3. 檢查後端日誌，應該會看到：
   ```
   [開發模式] 驗證碼已生成給 user@example.com: 123456
   ```

4. 輸入驗證碼進行驗證

### 測試 Supabase OTP

1. 確保 Supabase Dashboard 中 OTP 註冊已啟用

2. 停止後端服務（或修改代碼優先使用 Supabase）

3. 在應用程式中點擊「發送驗證碼」

4. 檢查郵件收件箱（包括垃圾郵件資料夾）

## 故障排除

### 問題：後端 API 連接失敗

**解決方案**：
- 確認後端服務正在運行
- 檢查 `backend/main.py` 中的 `backendUrl` 是否正確
- 確認防火牆允許連接

### 問題：Supabase OTP 仍然失敗

**解決方案**：
- 檢查 Supabase Dashboard 設定
- 確認 Email Provider 已啟用
- 檢查 Supabase 計劃限制
- 使用後端 API 作為替代方案

### 問題：驗證碼過期

**解決方案**：
- 驗證碼有效期為 10 分鐘
- 如果過期，重新發送驗證碼
- 可以調整 `backend/main.py` 中的過期時間

## 完成檢查清單

- [ ] 選擇驗證碼發送方案（Supabase OTP 或後端 API）
- [ ] 如果使用 Supabase OTP，確認 Dashboard 設定正確
- [ ] 如果使用後端 API，確認後端服務正在運行
- [ ] 測試發送驗證碼功能
- [ ] 測試驗證碼驗證功能
- [ ] 生產環境：整合專業郵件服務
- [ ] 生產環境：使用 Redis 或資料庫存儲驗證碼

