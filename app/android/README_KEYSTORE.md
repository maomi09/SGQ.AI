# Android Keystore 設定說明

## 快速開始

### 步驟 1：創建 Keystore

在 `app/android/` 目錄下執行：

```powershell
.\create-keystore.ps1
```

按照提示輸入資訊：
- Keystore 密碼（至少 6 個字元，請記住）
- Key 密碼（通常與 keystore 密碼相同，按 Enter 使用相同密碼）
- 您的姓名
- 組織資訊等

Keystore 會創建在：`C:\Users\您的用戶名\sgq-release-key.jks`

### 步驟 2：創建 key.properties

在 `app/android/` 目錄下執行：

```powershell
.\create-key-properties.ps1
```

或手動創建 `key.properties` 檔案：

```properties
storePassword=您的keystore密碼
keyPassword=您的key密碼
keyAlias=sgq
storeFile=C:\\Users\\您的用戶名\\sgq-release-key.jks
```

**重要**：將 `您的用戶名` 替換為實際的 Windows 用戶名。

### 步驟 3：構建 App Bundle

```powershell
cd ..\..
flutter clean
flutter pub get
flutter build appbundle --release
```

生成的 AAB 檔案位置：
```
app/build/app/outputs/bundle/release/app-release.aab
```

---

## 手動創建 key.properties

如果腳本無法執行，可以手動創建 `app/android/key.properties` 檔案：

1. 在 `app/android/` 目錄下創建 `key.properties`
2. 複製以下內容並填入實際值：

```properties
storePassword=您的keystore密碼
keyPassword=您的key密碼
keyAlias=sgq
storeFile=C:\\Users\\您的用戶名\\sgq-release-key.jks
```

**注意**：
- Windows 路徑中的反斜線需要轉義為 `\\`
- 將 `您的用戶名` 替換為實際的 Windows 用戶名（例如：`maola`）

---

## 驗證設定

構建 App Bundle 時，如果看到以下訊息，表示簽名配置正確：

```
✓ Built build\app\outputs\bundle\release\app-release.aab
```

如果出現錯誤，檢查：
1. `key.properties` 檔案是否存在
2. 路徑是否正確（特別是 Windows 路徑中的反斜線）
3. 密碼是否正確
4. keystore 檔案是否存在

---

## 備份 Keystore

**非常重要**：請務必備份 keystore 檔案和密碼！

1. 將 `C:\Users\您的用戶名\sgq-release-key.jks` 備份到安全位置
2. 記錄 keystore 密碼和 key 密碼
3. 如果遺失 keystore，將無法更新已發布的應用程式

建議備份到：
- 雲端硬碟（加密）
- 外部硬碟
- 多個安全位置

---

## 常見問題

### Q: 腳本執行時出現編碼錯誤？

A: 使用以下命令執行：

```powershell
powershell -ExecutionPolicy Bypass -File ".\create-keystore.ps1"
```

### Q: 找不到 keytool？

A: 確認 Android Studio 已安裝，keytool 位於：
```
C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe
```

### Q: 構建時提示找不到 key.properties？

A: 確認檔案位於 `app/android/key.properties`，並且路徑正確。

### Q: 構建時提示密碼錯誤？

A: 檢查 `key.properties` 中的密碼是否與創建 keystore 時使用的密碼一致。

---

## 需要幫助？

如果遇到問題，請檢查：
1. Android Studio 是否已正確安裝
2. Flutter 環境是否配置正確
3. 檔案路徑是否正確
4. 密碼是否正確
