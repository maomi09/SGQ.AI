# Google Play Console 內部測試完整指南

## 前置需求

1. Google Play Console 開發者帳號（需要一次性註冊費 $25）
2. 已創建應用程式（在 Google Play Console 中）
3. 完成應用程式基本資訊設定

---

## 步驟 1：創建 Android 簽名金鑰（Keystore）

### 1.1 生成 Keystore

#### 方法 A：使用 PowerShell 腳本（Windows 推薦）

在 `app/android/` 目錄下執行：

```powershell
cd app\android
.\create-keystore.ps1
```

腳本會自動引導您完成 keystore 創建。

#### 方法 B：使用完整路徑（Windows）

如果 `keytool` 不在 PATH 中，使用完整路徑：

```powershell
cd app\android
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore "$env:USERPROFILE\sgq-release-key.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias sgq
```

#### 方法 C：使用命令列（macOS/Linux）

```bash
cd app/android
keytool -genkey -v -keystore ~/sgq-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias sgq
```

**重要資訊**：
- **Keystore 密碼**：請記住此密碼，之後需要用到（至少 6 個字元）
- **Key 別名**：`sgq`（或您選擇的名稱）
- **Key 密碼**：建議與 keystore 密碼相同（按 Enter 使用相同密碼）
- **姓名**：您的姓名或公司名稱
- **組織單位**：可選（按 Enter 跳過）
- **組織**：您的組織名稱
- **城市**：您的城市
- **州/省**：您的州或省
- **國家/地區代碼**：例如 `TW`（台灣）

**注意**：
- Keystore 檔案請妥善保管，遺失後無法更新應用程式
- 建議將 keystore 備份到安全的地方
- 不要將 keystore 提交到版本控制系統
- Windows 上 keystore 會創建在：`C:\Users\您的用戶名\sgq-release-key.jks`

### 1.2 創建 key.properties 檔案

在 `app/android/` 目錄下創建 `key.properties` 檔案：

```properties
storePassword=您的keystore密碼
keyPassword=您的key密碼
keyAlias=sgq
storeFile=路徑到您的keystore檔案
```

**範例**（Windows）：
```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=sgq
storeFile=C:\\Users\\您的用戶名\\sgq-release-key.jks
```

**快速創建 key.properties**（Windows PowerShell）：
```powershell
cd app\android
$keystorePath = "$env:USERPROFILE\sgq-release-key.jks"
$storePassword = Read-Host "輸入 Keystore 密碼" -AsSecureString
$keyPassword = Read-Host "輸入 Key 密碼（或按 Enter 使用相同密碼）" -AsSecureString

# 注意：此方法需要手動處理安全字串，建議直接編輯檔案
```

**或直接編輯檔案**：
1. 在 `app/android/` 目錄下創建 `key.properties`
2. 複製 `key.properties.example` 的內容
3. 填入實際的密碼和路徑

**範例**（macOS/Linux）：
```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=sgq
storeFile=/Users/maola/sgq-release-key.jks
```

**重要**：
- `key.properties` 已加入 `.gitignore`，不會被提交到版本控制
- 請妥善保管此檔案和 keystore

---

## 步驟 2：配置 Android 簽名

### 2.1 更新 build.gradle.kts

已自動更新 `app/android/app/build.gradle.kts`，添加了簽名配置。

### 2.2 驗證配置

確認 `app/android/app/build.gradle.kts` 包含：

```kotlin
signingConfigs {
    create("release") {
        val keystorePropertiesFile = rootProject.file("key.properties")
        val keystoreProperties = java.util.Properties()
        if (keystorePropertiesFile.exists()) {
            keystoreProperties.load(keystorePropertiesFile.inputStream())
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        // 其他 release 配置...
    }
}
```

---

## 步驟 3：更新應用程式資訊

### 3.1 更新應用程式名稱

在 `app/android/app/src/main/AndroidManifest.xml` 中：

```xml
<application
    android:label="SGQ AI"  <!-- 改為您的應用程式名稱 -->
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher">
```

### 3.2 更新版本號

在 `app/pubspec.yaml` 中：

```yaml
version: 1.0.0+1  # 格式：versionName+versionCode
```

**說明**：
- `1.0.0` = versionName（用戶看到的版本號）
- `1` = versionCode（內部版本號，每次上傳必須遞增）

**每次上傳新版本時**：
- versionName 可以保持不變或更新（例如：1.0.1）
- versionCode **必須**遞增（例如：1 → 2 → 3）

---

## 步驟 4：構建 App Bundle (AAB)

### 4.1 構建 Release AAB

```bash
cd app
flutter clean
flutter pub get
flutter build appbundle --release
```

**輸出位置**：
```
app/build/app/outputs/bundle/release/app-release.aab
```

### 4.2 驗證 AAB

可以使用以下工具驗證 AAB：
- [bundletool](https://github.com/google/bundletool)（Google 官方工具）

---

## 步驟 5：在 Google Play Console 設定應用程式

### 5.1 創建應用程式

1. 登入 [Google Play Console](https://play.google.com/console)
2. 點擊「建立應用程式」
3. 填寫應用程式資訊：
   - **應用程式名稱**：SGQ AI（或您的應用程式名稱）
   - **預設語言**：繁體中文
   - **應用程式或遊戲**：應用程式
   - **免費或付費**：免費
   - **同意政策**：勾選並繼續

### 5.2 完成應用程式內容

在「政策」→「應用程式內容」中完成：

1. **隱私權政策**
   - 需要提供隱私權政策 URL
   - 如果還沒有，可以暫時使用 GitHub Pages 或簡單的網頁

2. **資料安全**
   - 填寫資料收集和使用方式

3. **目標對象和內容**
   - 選擇目標年齡層
   - 選擇內容分級

### 5.3 設定應用程式資訊

在「主要資訊」中填寫：

- **應用程式名稱**：SGQ AI
- **簡短說明**：您的應用程式簡短描述
- **完整說明**：詳細的應用程式說明
- **應用程式圖示**：512x512 PNG（無透明度）
- **功能圖示**：1024x500 PNG（可選）
- **螢幕截圖**：至少 2 張（手機版）
  - 手機：至少 320dp 高，寬度 320-3840dp
  - 建議尺寸：1080x1920 或更高

---

## 步驟 6：上傳到內部測試

### 6.1 建立內部測試版本

1. 在 Google Play Console 中，前往「測試」→「內部測試」
2. 點擊「建立新的版本」
3. 上傳 `app-release.aab` 檔案
4. 填寫版本說明（例如：首次內部測試版本）

### 6.2 新增測試人員

1. 在「測試人員」標籤中
2. 點擊「建立郵件清單」
3. 添加測試人員的 Gmail 地址（用逗號分隔）
4. 或使用 Google 群組

**注意**：
- 內部測試最多 100 名測試人員
- 測試人員必須接受測試邀請

### 6.3 發布內部測試版本

1. 確認所有必填項目已完成
2. 點擊「審查版本」
3. 確認後點擊「開始推出內部測試」

**審查時間**：
- 通常 1-3 個工作天
- 首次上傳可能需要更長時間

---

## 步驟 7：測試人員安裝應用程式

### 7.1 接受測試邀請

測試人員會收到電子郵件邀請，需要：

1. 點擊郵件中的連結
2. 加入 Google Play 測試計劃
3. 在 Google Play 商店中搜尋您的應用程式
4. 或使用提供的連結直接安裝

### 7.2 安裝應用程式

測試人員可以：
- 從 Google Play 商店安裝（會顯示「測試版」標記）
- 使用提供的測試連結

---

## 常見問題

### Q: 上傳後顯示「需要審查」？

A: 這是正常的。Google 會審查所有應用程式，首次上傳可能需要 1-3 個工作天。

### Q: 審查被拒絕怎麼辦？

A: 查看拒絕原因，通常會說明需要修改的地方。常見原因：
- 缺少隱私權政策
- 應用程式名稱或說明不符合規範
- 缺少必要的權限說明

### Q: 如何更新版本？

A: 
1. 更新 `pubspec.yaml` 中的版本號（versionCode 必須遞增）
2. 重新構建 AAB：`flutter build appbundle --release`
3. 在 Google Play Console 中上傳新版本

### Q: 可以跳過內部測試直接發布嗎？

A: 可以，但不建議。內部測試可以：
- 在正式發布前發現問題
- 獲得早期反饋
- 測試安裝和更新流程

### Q: 內部測試和封閉測試有什麼區別？

A:
- **內部測試**：最多 100 人，審查最快
- **封閉測試**：最多 20,000 人，需要更完整的設定
- **開放測試**：無限制，任何人都可以加入

建議流程：內部測試 → 封閉測試 → 正式發布

---

## 檢查清單

上傳前確認：

- [ ] 已創建並配置 keystore
- [ ] `key.properties` 已正確設定
- [ ] `build.gradle.kts` 已配置簽名
- [ ] 應用程式名稱已更新
- [ ] 版本號已設定（versionCode 從 1 開始）
- [ ] 已構建 AAB 檔案
- [ ] Google Play Console 應用程式已創建
- [ ] 隱私權政策已提供
- [ ] 應用程式圖示和截圖已上傳
- [ ] 應用程式說明已填寫
- [ ] 測試人員清單已準備

---

## 後續步驟

### 內部測試通過後

1. **收集反饋**：詢問測試人員的使用體驗
2. **修復問題**：根據反饋修復 bug
3. **準備封閉測試**：擴大測試範圍
4. **準備正式發布**：完善應用程式資訊和行銷素材

### 版本更新流程

每次更新版本：

1. 更新 `pubspec.yaml` 中的版本號（versionCode +1）
2. 構建新的 AAB：`flutter build appbundle --release`
3. 在 Google Play Console 中上傳新版本
4. 填寫版本說明（說明更新內容）
5. 審查並發布

---

## 重要提醒

1. **Keystore 安全**：
   - 請妥善保管 keystore 檔案和密碼
   - 遺失後無法更新應用程式
   - 建議備份到多個安全位置

2. **版本號規則**：
   - versionCode 必須遞增
   - 不能回退版本號
   - 每次上傳必須使用新的 versionCode

3. **審查時間**：
   - 首次上傳：1-3 個工作天
   - 後續更新：通常更快（幾小時到 1 天）

4. **測試人員限制**：
   - 內部測試：最多 100 人
   - 封閉測試：最多 20,000 人

---

## 需要幫助？

如果遇到問題：

1. 查看 [Google Play Console 說明文件](https://support.google.com/googleplay/android-developer)
2. 檢查 [Flutter 官方文件](https://docs.flutter.dev/deployment/android)
3. 查看錯誤訊息和日誌

---

**祝您發布順利！**
