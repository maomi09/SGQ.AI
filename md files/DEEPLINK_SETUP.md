# Google 登入深度連結設定指南

## 問題說明

Google 登入後無法跳轉回應用程式，通常是因為深度連結（Deep Link）沒有正確配置。

## 已完成的配置

### 1. Android 配置（AndroidManifest.xml）

已在 `app/android/app/src/main/AndroidManifest.xml` 中添加深度連結配置：

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="com.example.app"
        android:host="login-callback" />
</intent-filter>
```

### 2. iOS 配置（Info.plist）

已在 `app/ios/Runner/Info.plist` 中添加 URL Scheme：

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

### 3. 代碼配置

在 `supabase_service.dart` 中使用：
```dart
redirectTo: 'com.example.app://login-callback'
```

## Supabase Redirect URLs 設定

在 Supabase Dashboard 中設定：

1. 前往 **Authentication** > **URL Configuration**
2. 在 **Redirect URLs** 中添加：
   ```
   com.example.app://login-callback
   https://iqmhqdkpultzyzurolwv.supabase.co/auth/v1/callback
   ```

## Google Cloud Console 設定

在 Google Cloud Console 的 OAuth 客戶端設定中：

1. **Web application** 的授權重新導向 URI：
   ```
   https://iqmhqdkpultzyzurolwv.supabase.co/auth/v1/callback
   ```

2. **Android** OAuth 客戶端（如需要）：
   - Package name: `com.example.app`
   - SHA-1 憑證指紋（開發環境）：
     ```bash
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```

3. **iOS** OAuth 客戶端（如需要）：
   - Bundle ID: `com.example.app`

## 測試步驟

1. **重新編譯應用程式**：
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **測試深度連結**（Android）：
   ```bash
   adb shell am start -W -a android.intent.action.VIEW -d "com.example.app://login-callback" com.example.app
   ```

3. **測試 Google 登入**：
   - 點擊 "Sign in with Google" 按鈕
   - 完成 Google 登入
   - 應該自動返回應用程式

## 常見問題

### Q: 還是無法跳轉回應用程式？
A: 檢查以下項目：
1. 確保已重新編譯應用程式（`flutter clean` 後重新編譯）
2. 確保 Supabase Redirect URLs 已正確設定
3. 確保 Google Cloud Console 的授權重新導向 URI 正確
4. 檢查應用程式日誌是否有錯誤訊息

### Q: Android 深度連結不工作？
A: 
1. 確保 `android:autoVerify="true"` 已設定
2. 檢查 package name 是否正確（`com.example.app`）
3. 嘗試使用 `adb` 測試深度連結

### Q: iOS 深度連結不工作？
A:
1. 確保 Info.plist 中的 URL Scheme 正確
2. 確保 Bundle ID 與 URL Scheme 一致
3. 在真機上測試（模擬器可能有問題）

## 替代方案

如果深度連結還是有問題，可以嘗試：

1. **使用 Supabase 的標準回調 URL**：
   ```dart
   redirectTo: 'https://iqmhqdkpultzyzurolwv.supabase.co/auth/v1/callback'
   ```
   然後在 Supabase Dashboard 中設定網站 URL 為應用程式的深度連結。

2. **使用 app_links 套件**（更進階）：
   添加 `app_links` 套件來更好地處理深度連結。

