# 上架前檢查清單

## 🔴 必須修改（否則無法上架）

### 1. 應用識別信息
- [ ] **Android**: 修改 `app/android/app/build.gradle.kts` 中的 `applicationId`（不能是 `com.example.app`）
- [ ] **iOS**: 在 Xcode 中修改 Bundle Identifier（不能是 `com.example.app`）
- [ ] 修改 `app/android/app/src/main/AndroidManifest.xml` 中的 `android:label`（應用名稱）
- [ ] 修改 `app/ios/Runner/Info.plist` 中的 `CFBundleDisplayName`（應用顯示名稱）
- [ ] 修改 `app/pubspec.yaml` 中的 `name`、`description`、`version`

### 2. 簽名配置
- [ ] **Android**: 生成簽名密鑰並配置 `build.gradle.kts`
- [ ] **Android**: 創建 `key.properties` 文件（不要提交到 Git）
- [ ] **iOS**: 在 Xcode 中配置自動簽名和 Team

### 3. API 配置
- [ ] 修改 `app/lib/config/app_config.dart` 中的後端 API URL（不能是 `localhost`）
- [ ] 確認 Supabase URL 和 Key 正確
- [ ] 移除所有硬編碼的 API Key

### 4. 應用圖標
- [ ] **Android**: 替換所有尺寸的應用圖標（`android/app/src/main/res/mipmap-*/ic_launcher.png`）
- [ ] **iOS**: 在 Xcode 中配置 AppIcon（1024x1024）

### 5. 啟動畫面
- [ ] **Android**: 配置啟動畫面
- [ ] **iOS**: 配置啟動畫面

## 🟡 強烈建議修改

### 6. 版本號
- [ ] 確認 `app/pubspec.yaml` 中的版本號格式正確（`major.minor.patch+buildNumber`）
- [ ] **Android**: 確認 `versionCode` 從 1 開始
- [ ] **iOS**: 確認版本號與 `pubspec.yaml` 一致

### 7. 權限聲明
- [ ] 檢查 `AndroidManifest.xml` 中的權限聲明是否正確
- [ ] 檢查 `Info.plist` 中的權限說明是否完整

### 8. 安全檢查
- [ ] 確認 `.env` 文件在 `.gitignore` 中
- [ ] 確認沒有硬編碼的敏感信息
- [ ] 確認後端 API 有適當的認證

## 🟢 上架準備

### 9. 應用商店資料
- [ ] 準備應用截圖（至少 3-5 張）
- [ ] 準備應用描述（簡短和完整版本）
- [ ] 準備隱私政策網頁 URL
- [ ] 準備應用圖標（512x512 for Play Store, 1024x1024 for App Store）
- [ ] 準備功能圖標（Play Store 需要 1024x500）

### 10. 測試
- [ ] 在真實設備上測試所有功能
- [ ] 測試登入/註冊流程
- [ ] 測試主要功能流程
- [ ] 測試在不同屏幕尺寸上的顯示
- [ ] 測試網絡錯誤處理

### 11. 構建發布版本
- [ ] **Android**: 執行 `flutter build appbundle --release`
- [ ] **iOS**: 在 Xcode 中構建 Archive
- [ ] 確認構建成功且沒有錯誤

---

## 📝 配置文件修改範例

### `app/lib/config/app_config.dart` 修改範例

```dart
class AppConfig {
  // Supabase 設定
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key';

  // 後端 API 設定
  // 生產環境：使用你的後端服務器 URL
  static const String backendApiUrl = 'https://api.yourdomain.com';
  
  // 或者根據環境動態設置
  static String get backendApiUrl {
    if (kDebugMode) {
      return 'http://localhost:8000';  // 開發環境
    } else {
      return 'https://api.yourdomain.com';  // 生產環境
    }
  }
}
```

### `app/android/app/build.gradle.kts` 修改範例

```kotlin
android {
    namespace = "com.yourcompany.yourapp"  // 修改這裡
    
    defaultConfig {
        applicationId = "com.yourcompany.yourapp"  // 修改這裡
        versionCode = 1
        versionName = "1.0.0"
    }
    
    signingConfigs {
        create("release") {
            // 配置簽名
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

---

## ⚠️ 重要提醒

1. **後端 API URL**: 生產環境不能使用 `localhost`，必須使用實際的服務器 URL
2. **API Key 安全**: 不要將 API Key 硬編碼在客戶端代碼中
3. **簽名密鑰**: Android 簽名密鑰文件非常重要，丟失後無法更新應用
4. **版本號**: 每次更新時必須遞增版本號
5. **測試**: 在真實設備上充分測試後再提交審核

---

## 🚀 快速上架命令

### Android
```bash
cd app
flutter clean
flutter pub get
flutter build appbundle --release
# 上傳 app/build/app/outputs/bundle/release/app-release.aab 到 Play Console
```

### iOS
```bash
cd app
flutter clean
flutter pub get
# 在 Xcode 中打開 ios/Runner.xcworkspace
# Product > Archive > Distribute App
```

---

完成所有檢查項後，即可開始上架流程！
