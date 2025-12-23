# 正式郵件功能配置指南

## 一、Supabase Dashboard 配置（必須完成）

### 1. 配置 Redirect URLs

1. 登入 [Supabase Dashboard](https://supabase.com/dashboard)
2. 前往 **Authentication** > **URL Configuration**
3. 在 **Redirect URLs** 中添加：
   ```
   com.example.app://reset-password
   com.example.app://
   ```
4. 點擊 **Save** 保存

### 2. 確認 Email Provider 已啟用

1. 前往 **Authentication** > **Providers**
2. 找到 **Email** 選項
3. 確認 **Enable email provider** 已啟用
4. **Confirm email** - 可以關閉（開發環境）或啟用（生產環境）

### 3. 配置 Email 模板（可選）

1. 前往 **Authentication** > **Email Templates**
2. 可以自定義以下模板：
   - **Reset Password** - 重設密碼郵件
   - **Magic Link** - OTP 郵件（用於註冊驗證碼）

## 二、功能說明

### 1. 忘記密碼功能

**工作流程：**
1. 用戶點擊「Forgot password」
2. 輸入電子郵件地址
3. 系統發送重設密碼郵件（通過 Supabase）
4. 用戶點擊郵件中的連結
5. 應用程式自動打開並導航到重設密碼頁面
6. 用戶輸入新密碼並確認
7. 密碼重設成功，返回登入頁面

**技術實現：**
- 使用 `resetPasswordForEmail` API
- 深度連結：`com.example.app://reset-password`
- 自動處理 `passwordRecovery` 事件

### 2. 註冊驗證碼功能

**工作流程：**
1. 用戶切換到「Sign up」
2. 輸入電子郵件地址
3. 點擊「發送驗證碼」
4. 系統發送 OTP 驗證碼到用戶郵件（通過 Supabase）
5. 用戶輸入收到的 6 位數驗證碼
6. 驗證成功後完成註冊

**技術實現：**
- 使用 Supabase OTP（One-Time Password）功能
- `signInWithOtp` 發送驗證碼
- `verifyOTP` 驗證驗證碼
- 驗證成功後才允許註冊

## 三、測試步驟

### 測試忘記密碼

1. 在登入頁面點擊「Forgot password」
2. 輸入已註冊的電子郵件地址
3. 點擊「發送重設密碼郵件」
4. 檢查電子郵件收件箱（包括垃圾郵件資料夾）
5. 點擊郵件中的重設密碼連結
6. 應用程式應該自動打開並顯示重設密碼頁面
7. 輸入新密碼並確認
8. 密碼重設成功後返回登入頁面

### 測試註冊驗證碼

1. 在登入頁面切換到「Sign up」
2. 輸入電子郵件地址
3. 點擊「發送驗證碼」
4. 檢查電子郵件收件箱（包括垃圾郵件資料夾）
5. 輸入收到的 6 位數驗證碼
6. 填寫其他註冊資訊（姓名、學號、密碼）
7. 點擊「Sign up」完成註冊

## 四、常見問題

### Q1: 收不到郵件

**解決方案：**
- 檢查 Supabase Dashboard 中的 Email 服務狀態
- 檢查垃圾郵件資料夾
- 確認 Email Provider 已啟用
- 檢查 Supabase 的每日郵件發送限制（免費版有限制）
- 確認 Redirect URL 已正確配置

### Q2: 點擊重設密碼連結無法跳轉

**解決方案：**
- 確認 Redirect URL `com.example.app://reset-password` 已添加到 Supabase Dashboard
- 確認 Android/iOS 的深度連結配置正確
- 檢查應用程式的 Bundle ID/Package Name 是否匹配

### Q3: OTP 驗證碼錯誤

**解決方案：**
- 確認驗證碼是 6 位數
- 檢查驗證碼是否過期（通常 5-10 分鐘有效）
- 確認輸入的驗證碼與郵件中的一致
- 如果過期，重新發送驗證碼

### Q4: 註冊時驗證碼驗證成功但註冊失敗

**解決方案：**
- OTP 驗證和註冊是分開的步驟
- OTP 驗證成功後，還需要完成註冊流程
- 檢查註冊時的其他錯誤訊息

## 五、Supabase 郵件限制

### 免費版限制
- 每日郵件發送數量有限制
- 建議在生產環境升級到付費計劃

### 生產環境建議
1. 升級 Supabase 計劃以獲得更多郵件配額
2. 或整合第三方郵件服務（SendGrid、Mailgun 等）
3. 使用 Supabase Edge Functions 發送郵件

## 六、安全建議

1. **驗證碼過期時間**：Supabase OTP 默認有過期時間
2. **發送頻率限制**：Supabase 自動處理，防止濫用
3. **密碼強度**：確保新密碼符合要求（至少 6 個字符）
4. **深度連結驗證**：Supabase 自動驗證重設密碼 token

## 七、完成檢查清單

- [ ] 在 Supabase Dashboard 添加 Redirect URL: `com.example.app://reset-password`
- [ ] 確認 Email Provider 已啟用
- [ ] 測試忘記密碼郵件發送
- [ ] 測試點擊重設密碼連結跳轉
- [ ] 測試註冊驗證碼郵件發送
- [ ] 測試 OTP 驗證碼驗證
- [ ] 確認所有功能正常工作

## 八、技術細節

### 深度連結處理
當用戶點擊郵件中的重設密碼連結時：
1. Supabase 會觸發 `passwordRecovery` 事件
2. 應用程式監聽此事件並自動導航到重設密碼頁面
3. Supabase 會自動處理 token 驗證

### OTP 驗證流程
1. `signInWithOtp` 發送驗證碼到郵件
2. 用戶輸入驗證碼
3. `verifyOTP` 驗證驗證碼
4. 驗證成功後，可以進行註冊

### 密碼重設流程
1. `resetPasswordForEmail` 發送重設密碼郵件
2. 用戶點擊郵件中的連結
3. Supabase 處理 token 並觸發 `passwordRecovery` 事件
4. 應用程式導航到重設密碼頁面
5. 用戶輸入新密碼
6. `updateUser` 更新密碼

