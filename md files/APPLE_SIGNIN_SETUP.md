# Sign in with Apple 配置指南

本指南將幫助您配置 Sign in with Apple 功能。

## 前置需求

1. Apple Developer 帳號（年費 $99 USD）
2. 已配置的 Supabase 專案
3. Flutter 應用程式（iOS 和/或 Android）

## 步驟 1: Apple Developer 設定

### 1.1 建立 App ID

1. 登入 [Apple Developer Portal](https://developer.apple.com/account/)
2. 前往 **Certificates, Identifiers & Profiles**
3. 選擇 **Identifiers** > **App IDs**
4. 點擊 **+** 建立新的 App ID
5. 選擇 **App** 類型
6. 填寫資訊：
   - **Description**: SGQ AI App
   - **Bundle ID**: `com.sgqai.app`（必須與您的應用程式 Bundle ID 一致）
7. 在 **Capabilities** 中勾選 **Sign In with Apple**
8. 點擊 **Continue** 並 **Register**

### 1.2 建立 Service ID（用於 Supabase）

1. 在 **Identifiers** 中選擇 **Services IDs**
2. 點擊 **+** 建立新的 Service ID
3. 填寫資訊：
   - **Description**: SGQ AI Supabase Service
   - **Identifier**: `com.sgqai.app.supabase`（建議格式：`your.bundle.id.supabase`）
4. 勾選 **Sign In with Apple**
5. 點擊 **Configure** 設定：
   - **Primary App ID**: 選擇步驟 1.1 建立的 App ID
   - **Website URLs**:
     - **Domains and Subdomains**: `iqmhqdkpultzyzurolwv.supabase.co`
     - **Return URLs**: `https://iqmhqdkpultzyzurolwv.supabase.co/auth/v1/callback`
6. 點擊 **Save** 並 **Continue**
7. 如果出現 **"Register your email sources"** 頁面：
   - **Domains and Subdomains**: 填寫 `iqmhqdkpultzyzurolwv.supabase.co`
     - 這是 Supabase 的域名，用於 Apple 的私密電子郵件轉發服務
   - **Email Addresses**: 可以留空或填寫您的管理員電子郵件（例如：`sgqaiapp@gmail.com`）
     - 如果留空，Apple 仍會使用域名進行驗證
   - 點擊 **Next** 繼續
8. 完成後點擊 **Register**
9. **重要**：如果看到 Email Sources 列表，您可能會注意到：
   - Supabase 域名（`iqmhqdkpultzyzurolwv.supabase.co`）的 SPF 狀態可能顯示為失敗（紅色 X）
   - 這是**正常的**，因為 Supabase 的域名不是您直接控制的
   - **這不會影響 Sign in with Apple 的基本登入功能**
   - 如果您的電子郵件地址（如 `sgqaiapp@gmail.com`）顯示 SPF 成功（綠色勾），這就足夠了
   - 您可以繼續進行下一步配置，SPF 驗證失敗不會阻止 Sign in with Apple 的使用

### 1.3 建立 Key（用於 Supabase）

**重要前置條件**：在建立 Key 之前，必須先完成步驟 1.1（建立 App ID）並確保 App ID 已啟用 Sign in with Apple。

1. 在 **Certificates, Identifiers & Profiles** 中選擇 **Keys**
2. 點擊 **+** 建立新的 Key
3. 填寫資訊：
   - **Key Name**: SGQ AI Supabase Key
   - 勾選 **Sign In with Apple**
4. 點擊 **Configure**：
   - **Primary App ID**: 應該會顯示您在步驟 1.1 建立的 App ID
   - 如果顯示 "There are no identifiers available that can be associated with the key"：
     - **解決方案 1**：確認步驟 1.1 的 App ID 已建立並啟用 Sign in with Apple
     - **解決方案 2**：返回 **Identifiers** > **App IDs**，確認您的 App ID：
       - 狀態為 **Active**
       - 已勾選 **Sign In with Apple** capability
       - 如果未勾選，點擊 App ID 進入編輯，勾選 **Sign In with Apple** 並保存
     - **解決方案 3**：等待幾分鐘讓 Apple 系統同步，然後重新嘗試
5. 選擇 App ID 後，點擊 **Save** 並 **Continue**，然後 **Register**
6. **重要**：下載 `.p8` 檔案（只能下載一次，請妥善保管）
7. 記錄 **Key ID**（10 個字元的字串）

## 步驟 2: Supabase 後端配置

### 2.1 在 Supabase Dashboard 中配置

1. 登入 [Supabase Dashboard](https://app.supabase.com/)
2. 選擇您的專案
3. 前往 **Authentication** > **Providers**
4. 找到 **Apple** 並點擊啟用
5. 填寫以下資訊：
   - **Enabled**: 開啟
   - **Client ID (Service ID)**: 輸入步驟 1.2 建立的 Service ID（例如：`com.sgqai.app.supabase`）
   - **Team ID**: 在 Apple Developer Portal 右上角可以找到（10 個字元的字串）
   - **Key ID**: 輸入步驟 1.3 記錄的 Key ID
   - **Private Key**: 貼上步驟 1.3 下載的 `.p8` 檔案內容
     - 檔案內容格式：
       ```
       -----BEGIN PRIVATE KEY-----
       [您的私鑰內容]
       -----END PRIVATE KEY-----
       ```
6. 點擊 **Save**

### 2.2 設定 Redirect URLs

1. 在 Supabase Dashboard 中前往 **Authentication** > **URL Configuration**
2. 在 **Redirect URLs** 中添加：
   - `com.sgqai.app://login-callback`
   - `https://iqmhqdkpultzyzurolwv.supabase.co/auth/v1/callback`
3. 點擊 **Save**

## 步驟 3: iOS 應用配置

### 3.1 確認 Bundle ID

確認您的 iOS 應用 Bundle ID 與 Apple Developer 中設定的 App ID 一致：

1. 開啟 Xcode 專案：`app/ios/Runner.xcworkspace`
2. 選擇 **Runner** target
3. 在 **General** 標籤中確認 **Bundle Identifier** 為 `com.sgqai.app`

### 3.2 啟用 Sign in with Apple Capability

1. 在 Xcode 中選擇 **Runner** target
2. 前往 **Signing & Capabilities** 標籤
3. 點擊 **+ Capability**
4. 選擇 **Sign In with Apple**
5. 確認已自動添加

### 3.3 更新 Info.plist（已包含在專案中）

`app/ios/Runner/Info.plist` 已經包含必要的 URL Scheme 配置：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.sgqai.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.sgqai.app</string>
        </array>
    </dict>
</array>
```

## 步驟 4: Android 應用配置（可選）

Sign in with Apple 在 Android 上也可以使用，但需要額外配置。

### 4.1 更新 AndroidManifest.xml

`app/android/app/src/main/AndroidManifest.xml` 已經包含必要的深度連結配置：

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="com.sgqai.app" />
</intent-filter>
```

### 4.2 確認 Application ID

確認 `app/android/app/build.gradle.kts` 中的 `applicationId` 為 `com.sgqai.app`

## 步驟 5: 測試配置

### 5.1 測試 iOS

1. 在實體 iOS 設備上運行應用程式（Sign in with Apple 在模擬器上可能無法正常工作）
2. 點擊「Sign in with Apple」按鈕
3. 應該會出現 Apple 登入對話框
4. 完成登入流程

### 5.2 測試 Android

1. 在 Android 設備上運行應用程式
2. 點擊「Sign in with Apple」按鈕
3. 應該會開啟瀏覽器進行 Apple 登入
4. 完成登入後會自動返回應用程式

## 常見問題

### Q1: 出現 "Invalid client" 錯誤

**解決方案**：
- 確認 Supabase 中的 Client ID (Service ID) 與 Apple Developer 中的 Service ID 完全一致
- 確認 Service ID 已正確配置 Sign In with Apple

### Q2: 出現 "Invalid redirect_uri" 錯誤

**解決方案**：
- 確認 Supabase Redirect URLs 中包含 `com.sgqai.app://login-callback`
- 確認 Apple Developer 中的 Return URLs 包含 Supabase callback URL

### Q3: iOS 模擬器無法使用 Sign in with Apple

**解決方案**：
- Sign in with Apple 在模擬器上可能無法正常工作
- 請在實體 iOS 設備上測試

### Q4: 私鑰格式錯誤

**解決方案**：
- 確認 `.p8` 檔案內容包含完整的 `-----BEGIN PRIVATE KEY-----` 和 `-----END PRIVATE KEY-----`
- 確認沒有額外的空格或換行

### Q5: Team ID 找不到

**解決方案**：
- 在 Apple Developer Portal 右上角點擊您的帳號名稱
- Team ID 會顯示在彈出視窗中（10 個字元的字串）

## 重要注意事項

1. **私鑰安全**：`.p8` 私鑰檔案只能下載一次，請妥善保管
2. **Bundle ID 一致性**：確保所有地方的 Bundle ID 都一致
3. **測試環境**：Sign in with Apple 在開發環境和生產環境使用相同的配置
4. **審查要求**：如果您的應用使用第三方登入（如 Google），Apple 要求必須提供 Sign in with Apple 作為選項

## 參考資源

- [Apple Sign In Documentation](https://developer.apple.com/sign-in-with-apple/)
- [Supabase Apple Provider Documentation](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Flutter Sign In with Apple Package](https://pub.dev/packages/sign_in_with_apple)
