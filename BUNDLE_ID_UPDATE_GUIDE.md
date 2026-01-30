# Bundle ID 更新指南

當您需要更改應用程式的 Bundle ID 時，請按照以下步驟更新所有相關設定。

## 快速更新步驟

### 步驟 1：更新程式碼中的 Bundle ID

在 `app/lib/config/app_config.dart` 中更新 `bundleId`：

```dart
static const String bundleId = '你的新BundleID';
```

**重要**：程式碼中的深度連結會自動使用這個設定，無需手動修改。

### 步驟 2：更新 iOS 設定

#### 2.1 更新 Info.plist

檔案位置：`app/ios/Runner/Info.plist`

找到 `CFBundleURLSchemes` 區塊並更新：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>你的新BundleID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>你的新BundleID</string>
        </array>
    </dict>
</array>
```

#### 2.2 更新 Xcode 專案設定

1. 打開 `app/ios/Runner.xcworkspace` 在 Xcode 中
2. 選擇 **Runner** 專案（左側導航欄）
3. 選擇 **Runner** target
4. 打開 **General** 標籤
5. 在 **Identity** 區塊中，更新 **Bundle Identifier** 為新的值
6. 或者直接在 `app/ios/Runner.xcodeproj/project.pbxproj` 中搜尋並替換所有 `PRODUCT_BUNDLE_IDENTIFIER` 的值

### 步驟 3：更新 Android 設定

#### 3.1 更新 AndroidManifest.xml

檔案位置：`app/android/app/src/main/AndroidManifest.xml`

找到深度連結的 `intent-filter` 並更新 `android:scheme`：

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="你的新BundleID" />
</intent-filter>
```

#### 3.2 更新 build.gradle.kts

檔案位置：`app/android/app/build.gradle.kts`

更新 `applicationId`：

```kotlin
defaultConfig {
    applicationId = "你的新BundleID"
    // ... 其他設定
}
```

#### 3.3 更新 MainActivity.kt 的 package name（可選）

檔案位置：`app/android/app/src/main/kotlin/com/example/app/MainActivity.kt`

如果更改了 package name，需要：
1. 更新檔案中的 `package` 宣告
2. 移動檔案到對應的目錄結構

**注意**：如果只是更改 Bundle ID 而不更改 package name，可以跳過此步驟。

### 步驟 4：更新 Supabase 設定

1. 登入 [Supabase Dashboard](https://supabase.com/dashboard)
2. 選擇您的專案
3. 前往 **Authentication** > **URL Configuration**
4. 在 **Redirect URLs** 中：
   - 移除舊的 Bundle ID URL（例如：`舊BundleID://login-callback`）
   - 添加新的 Bundle ID URL：
     ```
     你的新BundleID://login-callback
     你的新BundleID://reset-password
     你的新BundleID://
     ```
5. 點擊 **Save** 保存

### 步驟 5：更新 Google Cloud Console 設定（如果使用 Google 登入）

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 選擇您的專案
3. 前往 **APIs & Services** > **Credentials**
4. 找到您的 **iOS OAuth 2.0 Client ID**
5. 更新 **Bundle ID** 為新的值
6. 如果使用 Android，更新 **Android OAuth 2.0 Client ID** 的 **Package name**

### 步驟 6：重新編譯應用程式

完成所有設定後，重新編譯應用程式：

```bash
cd app
flutter clean
flutter pub get
flutter build ios --no-codesign
flutter build apk  # 如果是 Android
```

## 檢查清單

更新 Bundle ID 時，請確認以下項目：

- [ ] `app/lib/config/app_config.dart` 中的 `bundleId` 已更新
- [ ] `app/ios/Runner/Info.plist` 中的 `CFBundleURLSchemes` 已更新
- [ ] Xcode 專案中的 `PRODUCT_BUNDLE_IDENTIFIER` 已更新
- [ ] `app/android/app/src/main/AndroidManifest.xml` 中的 `android:scheme` 已更新
- [ ] `app/android/app/build.gradle.kts` 中的 `applicationId` 已更新
- [ ] Supabase Dashboard 中的 Redirect URLs 已更新
- [ ] Google Cloud Console 中的 OAuth 設定已更新（如果使用）
- [ ] 已執行 `flutter clean` 並重新編譯

## 常見問題

### Q: 更新後 Google 登入無法跳轉回應用程式？

A: 請確認：
1. Supabase Dashboard 中的 Redirect URLs 已更新為新的 Bundle ID
2. Google Cloud Console 中的 iOS Bundle ID 已更新
3. 已完全重新編譯並安裝應用程式（不是只重新運行）

### Q: 更新後忘記密碼功能無法跳轉？

A: 請確認 Supabase Dashboard 中的 Redirect URLs 包含：
```
你的新BundleID://reset-password
```

### Q: 如何確認 Bundle ID 是否正確設定？

A: 可以檢查：
1. iOS: 在 Xcode 中查看專案的 Bundle Identifier
2. Android: 在 `build.gradle.kts` 中查看 `applicationId`
3. 程式碼: 在 `app_config.dart` 中查看 `bundleId`

## 注意事項

1. **備份**：在更改 Bundle ID 之前，建議先備份專案或建立 git commit
2. **測試**：更改後務必完整測試所有使用深度連結的功能（Google 登入、忘記密碼等）
3. **一致性**：確保所有地方的 Bundle ID 都一致，否則深度連結將無法正常工作
4. **App Store / Play Store**：如果應用程式已經上架，更改 Bundle ID 需要建立新的應用程式條目
