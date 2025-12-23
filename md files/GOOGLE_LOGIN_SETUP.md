# Google 登入設定指南

## 前置需求

1. Google Cloud Console 專案
2. Supabase 專案已設定

## 設定步驟

### 步驟 1：在 Google Cloud Console 設定

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 建立新專案或選擇現有專案
3. 啟用 **Google+ API**
4. 前往 **Credentials** > **Create Credentials** > **OAuth client ID**
5. 選擇應用程式類型：
   - **Web application**（用於 Supabase）
   - **Android**（用於 Android 應用程式）
   - **iOS**（用於 iOS 應用程式）
6. 設定授權重新導向 URI：
   - `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
   - 將 `YOUR_PROJECT_REF` 替換為您的 Supabase 專案參考 ID
7. 複製 **Client ID** 和 **Client Secret**

### 步驟 2：在 Supabase 中設定 Google OAuth

1. 登入 Supabase Dashboard
2. 前往 **Authentication** > **Providers**
3. 找到 **Google** 並啟用
4. 填入：
   - **Client ID (for OAuth)**: 從 Google Cloud Console 複製的 Client ID
   - **Client Secret (for OAuth)**: 從 Google Cloud Console 複製的 Client Secret
5. 點擊 **Save**

### 步驟 3：設定 Android 應用程式（如需要）

1. 在 Google Cloud Console 中建立 **Android** OAuth client ID
2. 需要 **SHA-1 憑證指紋**：
   ```bash
   # 開發環境
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   
   # 生產環境
   keytool -list -v -keystore your-release-key.keystore -alias your-key-alias
   ```
3. 在 `android/app/build.gradle` 中設定：
   ```gradle
   android {
       defaultConfig {
           // ... 其他設定
           manifestPlaceholders = [
               'googleClientId': 'YOUR_ANDROID_CLIENT_ID'
           ]
       }
   }
   ```

### 步驟 4：設定 iOS 應用程式（如需要）

1. 在 Google Cloud Console 中建立 **iOS** OAuth client ID
2. 需要 **Bundle ID**（例如：`com.example.app`）
3. 在 `ios/Runner/Info.plist` 中設定：
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>io.supabase.app</string>
           </array>
       </dict>
   </array>
   ```

### 步驟 5：測試 Google 登入

1. 執行應用程式
2. 點擊 "Sign in with Google" 按鈕
3. 應該會開啟瀏覽器進行 Google 登入
4. 登入成功後會自動返回應用程式

## 常見問題

### Q: 登入後沒有自動返回應用程式？
A: 檢查 `redirectTo` URL 是否正確設定。在 `supabase_service.dart` 中：
```dart
redirectTo: 'io.supabase.app://login-callback/',
```

### Q: 出現 "redirect_uri_mismatch" 錯誤？
A: 確保在 Google Cloud Console 中設定的授權重新導向 URI 與 Supabase 設定一致。

### Q: Android 應用程式無法使用 Google 登入？
A: 確保：
1. 已建立 Android OAuth client ID
2. SHA-1 憑證指紋已正確設定
3. Package name 與應用程式一致

### Q: iOS 應用程式無法使用 Google 登入？
A: 確保：
1. 已建立 iOS OAuth client ID
2. Bundle ID 已正確設定
3. URL Scheme 已正確配置

## 注意事項

1. **開發環境**：使用 `LaunchMode.externalApplication` 會在外部瀏覽器開啟
2. **生產環境**：可以考慮使用 `LaunchMode.inAppWebView` 在應用程式內開啟
3. **安全性**：不要將 Client Secret 提交到版本控制系統
4. **測試**：建議先在開發環境測試，確認無誤後再部署到生產環境

