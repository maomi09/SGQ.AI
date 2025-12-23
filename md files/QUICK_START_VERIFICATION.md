# 驗證碼功能快速啟動指南

## 問題說明

如果看到錯誤訊息：「OTP 註冊功能未啟用。請在 Supabase Dashboard 中啟用，或確保後端 API 正在運行。」

這表示需要啟動後端服務來發送驗證碼。

## 快速解決方案

### 方案 1：啟動後端服務（推薦，立即可用）

1. **打開終端機**，進入後端目錄：
   ```bash
   cd backend
   ```

2. **啟動後端服務**：
   ```bash
   uvicorn main:app --reload
   ```

3. **確認服務運行**：
   應該會看到類似以下的訊息：
   ```
   INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
   INFO:     Started reloader process
   ```

4. **在應用程式中測試**：
   - 輸入電子郵件
   - 點擊「發送驗證碼」
   - 檢查後端終端，會顯示驗證碼（開發模式）
   - 輸入驗證碼完成註冊

### 方案 2：啟用 Supabase OTP（需要配置）

1. 登入 [Supabase Dashboard](https://supabase.com/dashboard)
2. 前往 **Authentication** > **Providers**
3. 找到 **Email** 選項
4. 確認以下設定：
   - ✅ **Enable email provider** 已啟用
   - ✅ **Enable sign ups** 已啟用

## 開發模式說明

在開發模式下，驗證碼會：
- 顯示在後端終端日誌中
- 顯示在應用程式的 SnackBar 中（綠色提示）

**範例輸出**：
```
[開發模式] 驗證碼已生成給 user@example.com: 123456
```

## 常見問題

### Q: 後端服務啟動失敗

**解決方案**：
- 確認已安裝 Python 和所需套件：
  ```bash
  pip install fastapi uvicorn python-dotenv supabase openai
  ```

### Q: 連接被拒絕（Connection refused）

**解決方案**：
- 確認後端服務正在運行
- 確認端口 8000 未被其他程式占用
- 檢查防火牆設定

### Q: 驗證碼過期

**解決方案**：
- 驗證碼有效期為 10 分鐘
- 如果過期，重新發送驗證碼

## 生產環境建議

生產環境應：
1. 整合專業郵件服務（SendGrid、Mailgun 等）
2. 使用 Redis 或資料庫存儲驗證碼
3. 移除開發模式的驗證碼顯示

詳細配置請參考 `VERIFICATION_CODE_SETUP.md`

