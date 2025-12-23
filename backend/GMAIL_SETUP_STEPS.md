# Gmail SMTP 設定步驟（詳細圖文說明）

## 錯誤訊息
如果看到 `535 BadCredentials` 錯誤，表示認證失敗，通常是因為沒有使用應用程式密碼。

## 完整設定步驟

### 步驟 1：啟用兩步驟驗證

1. 登入您的 Gmail 帳號
2. 前往：https://myaccount.google.com/security
3. 找到「兩步驟驗證」區塊
4. 如果顯示「關閉」，點擊「開始使用」並完成設定
5. 如果已經啟用，會顯示「開啟」✓

### 步驟 2：生成應用程式密碼

1. 在「兩步驟驗證」啟用後，回到「安全性」頁面
2. 找到「應用程式密碼」區塊（在「兩步驟驗證」下方）
3. 點擊「應用程式密碼」
4. 如果第一次使用，可能需要：
   - 輸入您的 Gmail 密碼確認
   - 選擇「郵件」
   - 選擇「其他（自訂名稱）」
   - 輸入名稱（例如：AI-APP-Backend）
   - 點擊「產生」
5. **重要**：複製生成的 16 位密碼（格式：xxxx xxxx xxxx xxxx）
   - 這個密碼只會顯示一次！
   - 如果忘記，需要刪除舊的並重新生成

### 步驟 3：設定 .env 檔案

在 `backend` 目錄下創建或編輯 `.env` 檔案：

```env
SMTP_ENABLED=true
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=xxxx xxxx xxxx xxxx
SMTP_FROM_EMAIL=your_email@gmail.com
ENVIRONMENT=development
```

**重要注意事項**：
- `SMTP_USERNAME`：您的完整 Gmail 地址（例如：user@gmail.com）
- `SMTP_PASSWORD`：16 位應用程式密碼（不是 Gmail 登入密碼）
  - 可以包含空格，也可以移除空格（兩者都可以）
  - 例如：`abcd efgh ijkl mnop` 或 `abcdefghijklmnop`
- `SMTP_FROM_EMAIL`：通常與 `SMTP_USERNAME` 相同

### 步驟 4：驗證設定

確認 `.env` 檔案中的設定：
- ✅ `SMTP_ENABLED=true`
- ✅ `SMTP_USERNAME` 是完整的 Gmail 地址
- ✅ `SMTP_PASSWORD` 是 16 位應用程式密碼（不是登入密碼）
- ✅ 沒有多餘的空格或引號

### 步驟 5：重啟後端服務

```bash
cd backend
uvicorn main:app --reload
```

### 步驟 6：測試

1. 在應用程式中輸入電子郵件
2. 點擊「發送驗證碼」
3. 檢查後端終端，應該看到：
   ```
   郵件已通過 SMTP 發送到 xxx@example.com
   ```
4. 檢查您的電子郵件收件匣

## 常見問題

### Q: 為什麼不能使用 Gmail 登入密碼？

A: Gmail 為了安全，不允許第三方應用程式使用登入密碼。必須使用應用程式密碼。

### Q: 應用程式密碼格式是什麼？

A: 16 位字符，格式為 `xxxx xxxx xxxx xxxx`（4組，每組4位），可以包含或不包含空格。

### Q: 如果忘記應用程式密碼怎麼辦？

A: 需要刪除舊的應用程式密碼並重新生成：
1. 前往「應用程式密碼」頁面
2. 找到對應的應用程式密碼
3. 點擊刪除
4. 重新生成新的

### Q: 仍然出現認證錯誤？

請檢查：
1. ✅ 兩步驟驗證已啟用
2. ✅ 使用的是應用程式密碼（16位），不是登入密碼
3. ✅ `.env` 檔案中的設定正確
4. ✅ 沒有多餘的空格或引號
5. ✅ 後端服務已重啟（讓 .env 變更生效）

### Q: 可以使用其他 Gmail 帳號嗎？

A: 可以，只要：
1. 該帳號已啟用兩步驟驗證
2. 已生成應用程式密碼
3. 在 `.env` 中正確設定

## 安全建議

1. **永遠不要將 `.env` 檔案提交到 Git**
2. **應用程式密碼只顯示一次，請妥善保存**
3. **如果應用程式密碼洩露，立即刪除並重新生成**

