# App Store 與 Play Store 上架完整指南

本文檔提供將 Flutter 應用上架到 App Store 和 Play Store 的完整步驟和配置說明。

---

## 📋 目錄

1. [上架前準備工作](#上架前準備工作)
2. [Android (Play Store) 上架步驟](#android-play-store-上架步驟)
3. [iOS (App Store) 上架步驟](#ios-app-store-上架步驟)
4. [配置文件修改清單](#配置文件修改清單)
5. [常見問題與解決方案](#常見問題與解決方案)

---

## 上架前準備工作

### 1. 開發者帳號註冊

#### Google Play Store
- 註冊費用：**一次性 $25 美元**
- 註冊網址：https://play.google.com/console/signup
- 審核時間：通常 1-2 個工作天

#### Apple App Store
- 註冊費用：**每年 $99 美元**
- 註冊網址：https://developer.apple.com/programs/
- 審核時間：通常 1-3 個工作天

### 2. 應用圖標和啟動畫面

#### 應用圖標尺寸要求

**Android:**
- `mipmap-mdpi/ic_launcher.png`: 48x48
- `mipmap-hdpi/ic_launcher.png`: 72x72
- `mipmap-xhdpi/ic_launcher.png`: 96x96
- `mipmap-xxhdpi/ic_launcher.png`: 144x144
- `mipmap-xxxhdpi/ic_launcher.png`: 192x192

**iOS:**
- 需要多種尺寸，建議使用工具生成：
  - 1024x1024 (App Store)
  - 各種設備尺寸（iPhone、iPad）

**推薦工具：**
- https://www.appicon.co/
- https://icon.kitchen/

#### 啟動畫面 (Splash Screen)
- Android: `android/app/src/main/res/drawable/launch_background.xml`
- iOS: `ios/Runner/Assets.xcassets/LaunchImage.imageset/`

### 3. 應用截圖準備

#### Google Play Store
- 至少 2 張截圖（最多 8 張）
- 手機：16:9 或 9:16 比例
- 平板：16:9 或 9:16 比例
- 最小尺寸：320px
- 最大尺寸：3840px

#### Apple App Store
- iPhone 6.7" (iPhone 14 Pro Max): 1290 x 2796
- iPhone 6.5" (iPhone 11 Pro Max): 1242 x 2688
- iPhone 5.5" (iPhone 8 Plus): 1242 x 2208
- iPad Pro 12.9": 2048 x 2732
- 至少需要 3 張截圖

### 4. 隱私政策

**必須準備：**
- 隱私政策網頁 URL（必須可公開訪問）
- 說明應用收集哪些數據
- 數據使用方式
- 第三方服務（如 Supabase、OpenAI）的使用說明

**建議使用：**
- GitHub Pages 託管
- 或自己的網站

### 5. 應用描述文案

準備以下內容：
- 應用名稱（簡短、易記）
- 應用描述（詳細說明功能）
- 關鍵字（用於搜索優化）
- 更新說明（版本更新時使用）

---

## Android (Play Store) 上架步驟

### 步驟 1: 修改應用配置

#### 1.1 修改 `app/android/app/build.gradle.kts`

```kotlin
android {
    namespace = "com.yourcompany.yourapp"  // 修改為你的應用 ID
    // ... 其他配置 ...

    defaultConfig {
        applicationId = "com.yourcompany.yourapp"  // 修改為你的應用 ID
        minSdk = 21  // 建議至少 21
        targetSdk = 34  // 使用最新的 targetSdk
        versionCode = 1  // 每次上傳新版本需遞增
        versionName = "1.0.0"  // 用戶可見的版本號
    }

    buildTypes {
        release {
            // 必須配置簽名
            signingConfig = signingConfigs.getByName("release")
            // 啟用代碼混淆（可選，但建議）
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file("your-release-key.jks")
            storePassword = "your-store-password"
            keyAlias = "your-key-alias"
            keyPassword = "your-key-password"
        }
    }
}
```

#### 1.2 生成簽名密鑰

```bash
# 在 app/android 目錄下執行
keytool -genkey -v -keystore your-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias your-key-alias
```

**重要：**
- 保存 `your-release-key.jks` 文件（非常重要！）
- 記住密碼和別名
- 建議將密鑰文件加入 `.gitignore`

#### 1.3 創建 `app/android/key.properties`（不要提交到 Git）

```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=your-key-alias
storeFile=your-release-key.jks
```

#### 1.4 修改 `app/android/app/build.gradle.kts` 讀取密鑰

```kotlin
// 在文件開頭添加
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... 其他配置 ...
    
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
}
```

#### 1.5 修改 `app/android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 添加權限說明 -->
    <uses-permission android:name="android.permission.INTERNET"/>
    
    <application
        android:label="你的應用名稱"  <!-- 修改應用名稱 -->
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- ... 其他配置 ... -->
    </application>
</manifest>
```

#### 1.6 修改 `app/pubspec.yaml`

```yaml
name: app
description: "你的應用描述"  # 修改描述
version: 1.0.0+1  # 版本號格式：major.minor.patch+buildNumber
```

### 步驟 2: 構建發布版本

```bash
cd app
flutter clean
flutter pub get
flutter build appbundle --release
```

生成的 AAB 文件位於：`app/build/app/outputs/bundle/release/app-release.aab`

### 步驟 3: 在 Google Play Console 上傳

1. 登入 https://play.google.com/console
2. 創建新應用
3. 填寫應用詳情：
   - 應用名稱
   - 簡短描述（80 字符）
   - 完整描述（4000 字符）
   - 圖標（512x512 PNG）
   - 功能圖標（1024x500 PNG）
   - 截圖
4. 設置內容分級
5. 設置定價和分發
6. 上傳 AAB 文件
7. 填寫隱私政策 URL
8. 提交審核

### 步驟 4: 測試版本（可選但建議）

在正式發布前，建議先發布到：
- **內部測試**：最多 100 個測試人員
- **封閉測試**：最多 1000 個測試人員
- **公開測試**：不限人數

---

## iOS (App Store) 上架步驟

### 步驟 1: 修改應用配置

#### 1.1 修改 Bundle Identifier

在 Xcode 中：
1. 打開 `ios/Runner.xcworkspace`
2. 選擇 Runner 項目
3. 在 General 標籤中修改 **Bundle Identifier**
   - 格式：`com.yourcompany.yourapp`
   - 必須與 Apple Developer 帳號中的 App ID 一致

#### 1.2 修改 `app/ios/Runner/Info.plist`

```xml
<key>CFBundleDisplayName</key>
<string>你的應用名稱</string>  <!-- 修改應用顯示名稱 -->

<key>CFBundleName</key>
<string>你的應用名稱</string>  <!-- 修改應用名稱 -->

<key>CFBundleIdentifier</key>
<string>com.yourcompany.yourapp</string>  <!-- 修改 Bundle ID -->
```

#### 1.3 修改 `app/pubspec.yaml`

```yaml
name: app
description: "你的應用描述"
version: 1.0.0+1
```

#### 1.4 配置 App Icons

在 Xcode 中：
1. 選擇 `Runner/Assets.xcassets/AppIcon.appiconset`
2. 拖入對應尺寸的圖標

或使用工具生成後替換文件。

### 步驟 2: 配置簽名和證書

#### 2.1 在 Apple Developer 網站創建 App ID

1. 登入 https://developer.apple.com/account
2. 前往 Certificates, Identifiers & Profiles
3. 創建新的 App ID
4. 選擇功能（如 Push Notifications、Sign in with Apple 等）

#### 2.2 在 Xcode 中配置自動簽名

1. 打開 `ios/Runner.xcworkspace`
2. 選擇 Runner 項目
3. 在 Signing & Capabilities 標籤中：
   - 勾選 "Automatically manage signing"
   - 選擇你的 Team
   - 確認 Bundle Identifier 正確

### 步驟 3: 構建發布版本

#### 3.1 使用 Xcode 構建

1. 在 Xcode 中選擇 Product > Archive
2. 等待構建完成
3. 在 Organizer 中選擇 Archive
4. 點擊 "Distribute App"
5. 選擇 "App Store Connect"
6. 選擇 "Upload"
7. 按照提示完成上傳

#### 3.2 或使用命令行構建

```bash
cd app
flutter clean
flutter pub get
flutter build ipa --release
```

### 步驟 4: 在 App Store Connect 配置

1. 登入 https://appstoreconnect.apple.com
2. 創建新應用：
   - 選擇平台：iOS
   - 應用名稱
   - 主要語言
   - Bundle ID（必須與 Xcode 中的一致）
   - SKU（唯一標識符）
3. 填寫應用資訊：
   - 應用描述
   - 關鍵字
   - 隱私政策 URL
   - 應用截圖
   - 應用圖標（1024x1024）
4. 設置定價和可用性
5. 提交審核

### 步驟 5: 提交審核

1. 在 App Store Connect 中選擇版本
2. 填寫審核資訊
3. 回答審核問題
4. 提交審核

---

## 配置文件修改清單

### 必須修改的文件

#### 1. `app/pubspec.yaml`
- [ ] 修改 `name`（應用包名）
- [ ] 修改 `description`（應用描述）
- [ ] 確認 `version`（版本號）

#### 2. `app/android/app/build.gradle.kts`
- [ ] 修改 `namespace`（應用 ID）
- [ ] 修改 `applicationId`（應用 ID）
- [ ] 配置簽名（release build）
- [ ] 設置 `versionCode` 和 `versionName`

#### 3. `app/android/app/src/main/AndroidManifest.xml`
- [ ] 修改 `android:label`（應用名稱）
- [ ] 確認權限聲明
- [ ] 確認 Deep Link 配置

#### 4. `app/ios/Runner/Info.plist`
- [ ] 修改 `CFBundleDisplayName`（應用顯示名稱）
- [ ] 修改 `CFBundleName`（應用名稱）
- [ ] 確認 `CFBundleIdentifier`（Bundle ID）

#### 5. `app/lib/config/app_config.dart`
- [ ] 確認 Supabase URL 和 Key 正確
- [ ] 確認後端 API URL（生產環境）
- [ ] **移除或保護 API Key**（不要硬編碼）

#### 6. 應用圖標
- [ ] Android: 替換所有尺寸的圖標
- [ ] iOS: 在 Xcode 中配置 AppIcon

#### 7. 啟動畫面
- [ ] Android: 配置啟動畫面
- [ ] iOS: 配置啟動畫面

### 重要安全檢查

- [ ] 移除所有硬編碼的 API Key
- [ ] 使用環境變數或安全的配置方式
- [ ] 確認後端 API 有適當的認證和授權
- [ ] 檢查日誌輸出，移除敏感信息
- [ ] 確認 `.env` 文件在 `.gitignore` 中

---

## 常見問題與解決方案

### Android 問題

#### 問題 1: 簽名錯誤
**解決方案：**
- 確認 `key.properties` 文件存在且配置正確
- 確認密鑰文件路徑正確
- 確認密碼和別名正確

#### 問題 2: 版本號衝突
**解決方案：**
- 每次上傳新版本時，`versionCode` 必須遞增
- 在 `pubspec.yaml` 中修改版本號

#### 問題 3: 權限被拒絕
**解決方案：**
- 在 `AndroidManifest.xml` 中聲明所需權限
- 在應用中請求運行時權限（Android 6.0+）

### iOS 問題

#### 問題 1: 簽名失敗
**解決方案：**
- 確認 Apple Developer 帳號已註冊
- 確認在 Xcode 中選擇了正確的 Team
- 確認 Bundle Identifier 與 App ID 一致

#### 問題 2: 構建失敗
**解決方案：**
- 執行 `flutter clean`
- 在 Xcode 中清理構建文件夾（Product > Clean Build Folder）
- 確認 CocoaPods 已更新：`cd ios && pod install`

#### 問題 3: 審核被拒
**常見原因：**
- 缺少隱私政策
- 功能不完整或崩潰
- 違反 App Store 審核指南

**解決方案：**
- 仔細閱讀審核反饋
- 修復問題後重新提交

---

## 版本更新流程

### Android
1. 修改 `app/pubspec.yaml` 中的版本號
2. 在 `build.gradle.kts` 中遞增 `versionCode`
3. 構建新的 AAB 文件
4. 在 Google Play Console 上傳新版本

### iOS
1. 修改 `app/pubspec.yaml` 中的版本號
2. 在 Xcode 中構建新的 Archive
3. 上傳到 App Store Connect
4. 提交審核

---

## 額外建議

1. **測試充分**：在真實設備上測試所有功能
2. **準備截圖**：使用真實設備截圖，不要使用模擬器
3. **撰寫更新說明**：每次更新時寫清楚新功能和修復
4. **監控崩潰**：考慮集成 Firebase Crashlytics 或其他崩潰報告工具
5. **分析數據**：考慮集成 Google Analytics 或 Firebase Analytics
6. **用戶反饋**：準備好處理用戶評論和反饋

---

## 參考資源

- [Flutter 發布文檔](https://docs.flutter.dev/deployment)
- [Google Play Console 幫助](https://support.google.com/googleplay/android-developer)
- [App Store Connect 幫助](https://developer.apple.com/support/app-store-connect/)
- [App Store 審核指南](https://developer.apple.com/app-store/review/guidelines/)

---

**祝上架順利！** 🚀
