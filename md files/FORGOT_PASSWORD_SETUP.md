# 忘記密碼和註冊驗證碼功能配置指南

## 一、忘記密碼功能配置

### 1. Supabase Dashboard 設定

#### 步驟 1：啟用 Email Provider
1. 登入 [Supabase Dashboard](https://supabase.com/dashboard)
2. 選擇您的專案
3. 前往 **Authentication** > **Providers**
4. 找到 **Email** 選項
5. 確認 **Enable email provider** 已啟用

#### 步驟 2：設定 Redirect URLs
1. 前往 **Authentication** > **URL Configuration**
2. 在 **Redirect URLs** 中添加以下 URL：
   ```
   com.example.app://reset-password
   ```
3. 點擊 **Save** 保存

#### 步驟 3：配置 Email 模板（可選）
1. 前往 **Authentication** > **Email Templates**
2. 找到 **Reset Password** 模板
3. 可以自定義郵件內容，但必須包含以下變數：
   - `{{ .ConfirmationURL }}` - 重設密碼的連結
   - `{{ .Email }}` - 用戶的電子郵件

### 2. 深度連結配置（Android）

在 `app/android/app/src/main/AndroidManifest.xml` 中確認已有以下配置：

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="com.example.app"
        android:host="reset-password" />
</intent-filter>
```

### 3. 深度連結配置（iOS）

在 `app/ios/Runner/Info.plist` 中確認已有 URL Scheme 配置（應該已經存在）：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.example.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.example.app</string>
        </array>
    </dict>
</array>
```

### 4. 處理重設密碼深度連結（可選）

如果需要處理用戶點擊郵件中的重設密碼連結，可以在 `main.dart` 中添加深度連結處理：

```dart
// 在 _AuthWrapperState 中添加
void _handlePasswordResetLink() async {
  // 處理重設密碼深度連結
  // 可以導航到重設密碼頁面
}
```

## 二、註冊驗證碼功能配置

### 當前狀態
目前驗證碼功能是**本地生成**的，驗證碼會顯示在 SnackBar 中（僅用於開發測試）。

### 生產環境配置（可選）

如果要真正發送驗證碼郵件，有以下選項：

#### 選項 1：使用 Supabase Edge Functions + Email Service
1. 創建 Supabase Edge Function 發送郵件
2. 整合 SendGrid、Mailgun 或其他郵件服務
3. 修改 `_sendVerificationCode` 方法調用 Edge Function

#### 選項 2：使用第三方郵件 API
1. 整合 SendGrid、Mailgun、AWS SES 等服務
2. 在後端 API 中實現發送驗證碼功能
3. 修改 `_sendVerificationCode` 方法調用 API

#### 選項 3：使用 Supabase Auth OTP（推薦）
可以改用 Supabase 的 OTP（One-Time Password）功能：

```dart
// 在 SupabaseService 中添加
Future<void> sendOTP(String email) async {
  await _client.auth.signInWithOtp(
    email: email,
    shouldCreateUser: false, // 僅發送 OTP，不創建用戶
  );
}

// 驗證 OTP
Future<AuthResponse> verifyOTP(String email, String token) async {
  return await _client.auth.verifyOTP(
    email: email,
    token: token,
    type: OtpType.signup,
  );
}
```

## 三、測試步驟

### 測試忘記密碼功能
1. 在登入頁面點擊「Forgot password」
2. 輸入已註冊的電子郵件地址
3. 點擊「發送重設密碼郵件」
4. 檢查電子郵件收件箱（包括垃圾郵件資料夾）
5. 點擊郵件中的重設密碼連結
6. 應該會跳轉到應用程式並顯示重設密碼頁面

### 測試註冊驗證碼功能
1. 在登入頁面切換到「Sign up」
2. 輸入電子郵件地址
3. 點擊「發送驗證碼」
4. 查看 SnackBar 中顯示的驗證碼（開發測試用）
5. 輸入驗證碼
6. 完成註冊

## 四、常見問題

### Q1: 收不到重設密碼郵件
**解決方案：**
- 檢查 Supabase Dashboard 中的 Email 服務是否正常
- 檢查垃圾郵件資料夾
- 確認 Redirect URL 已正確配置
- 檢查 Supabase 的 Email 發送限制（免費版有每日限制）

### Q2: 點擊重設密碼連結無法跳轉回應用
**解決方案：**
- 確認 Redirect URL 已添加到 Supabase Dashboard
- 確認 Android/iOS 的深度連結配置正確
- 檢查應用程式的 Bundle ID/Package Name 是否與深度連結匹配

### Q3: 驗證碼功能在生產環境如何實現？
**建議：**
- 使用 Supabase OTP 功能（最簡單）
- 或整合第三方郵件服務（SendGrid、Mailgun 等）
- 或使用後端 API 發送驗證碼

## 五、重要提醒

1. **開發環境**：目前驗證碼顯示在 SnackBar 中，僅用於測試
2. **生產環境**：必須整合真正的郵件發送服務
3. **安全性**：驗證碼應該有時效性（例如 5-10 分鐘過期）
4. **Rate Limiting**：建議添加發送頻率限制，防止濫用

## 六、下一步建議

1. ✅ 完成 Supabase Redirect URL 配置
2. ⚠️ 測試忘記密碼郵件發送功能
3. ⚠️ 決定註冊驗證碼的實現方式（OTP 或郵件服務）
4. ⚠️ 實現驗證碼過期機制
5. ⚠️ 添加發送頻率限制

