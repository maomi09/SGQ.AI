# Google 登入跳轉問題修復指南

## 問題描述

Google 登入完成後停留在授權頁面，無法跳轉回應用程式。URL 顯示：
```
https://iqmhqdkpultzyzurolwv.supabase.co/auth/v1/authorize?provider=google&redirect_to=com.example.app%3A%2F%2F&flow_type=pkce&...
```

## 已完成的修復

### 1. Android 深度連結配置更新

已更新 `AndroidManifest.xml`，移除 host 限制，允許所有 `com.example.app://` 開頭的深度連結：

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="com.example.app" />
</intent-filter>
```

### 2. 認證狀態監聽改進

已添加更完整的認證狀態監聽，包括：
- `signedIn` 事件
- `tokenRefreshed` 事件
- 應用程式啟動時的會話檢查

### 3. Google 登入流程優化

簡化了 Google 登入流程，移除不必要的延遲，讓深度連結回調自動處理認證。

## Supabase 設定檢查清單

請確認以下設定：

### 1. Redirect URLs
在 Supabase Dashboard > Authentication > URL Configuration 中，確保添加了：
```
com.example.app://
https://iqmhqdkpultzyzurolwv.supabase.co/auth/v1/callback
```

### 2. Site URL
在 Supabase Dashboard > Authentication > URL Configuration 中，設定：
```
com.example.app://
```

## 測試步驟

1. **完全重新編譯應用程式**：
   ```bash
   cd app
   flutter clean
   flutter pub get
   flutter run
   ```

2. **測試深度連結**（Android）：
   ```bash
   adb shell am start -W -a android.intent.action.VIEW -d "com.example.app://" com.example.app
   ```

3. **測試 Google 登入**：
   - 點擊 "Sign in with Google"
   - 完成 Google 登入
   - 應該自動返回應用程式

## 如果還是無法跳轉

### 方案 1：手動處理深度連結

如果自動跳轉還是有問題，可以手動在瀏覽器中完成登入後，複製 URL 中的參數並手動觸發深度連結。

### 方案 2：使用 Supabase 標準回調

修改 `supabase_service.dart` 中的 `redirectTo`：

```dart
redirectTo: 'https://iqmhqdkpultzyzurolwv.supabase.co/auth/v1/callback'
```

然後在 Supabase Dashboard 中設定 Site URL 為 `com.example.app://`。

### 方案 3：檢查瀏覽器設定

確保：
1. 預設瀏覽器允許打開應用程式
2. Android 的應用程式連結驗證已通過
3. 沒有其他應用程式攔截深度連結

## 調試建議

1. **檢查應用程式日誌**：
   - 查看是否有 "Auth state changed" 訊息
   - 查看是否有錯誤訊息

2. **檢查 Supabase 日誌**：
   - 在 Supabase Dashboard > Logs > Auth Logs 中查看認證日誌

3. **測試深度連結**：
   - 使用 `adb` 命令測試深度連結是否正常工作

## 常見問題

### Q: 深度連結測試成功，但 Google 登入後還是無法跳轉？
A: 可能是瀏覽器沒有正確處理深度連結。嘗試：
1. 清除瀏覽器快取
2. 使用不同的瀏覽器測試
3. 檢查 Android 的應用程式連結設定

### Q: 出現 "net::ERR_UNKNOWN_URL_SCHEME" 錯誤？
A: 這表示深度連結沒有正確配置。檢查：
1. AndroidManifest.xml 中的 intent-filter 是否正確
2. Info.plist 中的 URL Scheme 是否正確
3. 是否重新編譯了應用程式

