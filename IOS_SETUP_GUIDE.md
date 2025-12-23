# iOS 設定指南

## 前置需求

### 1. Mac 電腦
- macOS 10.15 或更高版本
- 至少 8GB RAM（建議 16GB）

### 2. Xcode
- 從 App Store 安裝 Xcode（最新版本）
- 打開 Xcode 並接受許可協議
- 安裝額外的組件（Xcode 會自動提示）

### 3. CocoaPods
```bash
sudo gem install cocoapods
```

### 4. Flutter iOS 工具
```bash
flutter doctor
```

確保 iOS 工具鏈顯示為已安裝。

## 設定步驟

### 步驟 1：安裝 iOS 依賴
```bash
cd app/ios
pod install
cd ../..
```

### 步驟 2：檢查可用設備
```bash
flutter devices
```

您應該會看到：
- iOS 模擬器列表
- 連接的 iPhone 設備（如果已連接）

### 步驟 3：運行應用程式

#### 在 iOS 模擬器上運行：
```bash
cd app
flutter run -d ios
```

#### 在真實 iPhone 設備上運行：
1. 連接 iPhone 到 Mac
2. 在 iPhone 上信任此電腦
3. 在 Xcode 中：
   - 打開 `app/ios/Runner.xcworkspace`
   - 選擇您的 iPhone 作為目標設備
   - 點擊運行按鈕

或使用命令行：
```bash
flutter run -d <device-id>
```

## 常見問題

### 問題 1：CocoaPods 安裝失敗
```bash
# 更新 Ruby
brew install ruby

# 重新安裝 CocoaPods
sudo gem install cocoapods
```

### 問題 2：簽名錯誤
1. 打開 `app/ios/Runner.xcworkspace` 在 Xcode 中
2. 選擇 Runner 專案
3. 在 "Signing & Capabilities" 標籤中：
   - 選擇您的開發團隊
   - 或創建新的 Bundle Identifier

### 問題 3：模擬器無法啟動
```bash
# 列出所有可用的模擬器
xcrun simctl list devices

# 啟動特定模擬器
open -a Simulator
```

## 在 Windows 上開發 iOS 的替代方案

### 1. 使用遠端 Mac
- MacStadium
- MacinCloud
- AWS EC2 Mac instances

### 2. 使用 Codemagic
1. 註冊 Codemagic 帳號
2. 連接 GitHub 倉庫
3. 配置 iOS 構建
4. 構建並下載 .ipa 文件

### 3. 使用 GitHub Actions（如果有 Mac runner）
配置 GitHub Actions 使用 Mac runner 進行構建。

## 測試建議

1. **在模擬器上測試基本功能**
   - 登入/註冊
   - 基本導航
   - UI 顯示

2. **在真實設備上測試**
   - 推送通知
   - 相機功能
   - 性能測試
   - 網路連接（特別是後端 API）

## 注意事項

- iOS 模擬器無法測試某些功能（如推送通知、相機）
- 真實設備測試需要 Apple Developer 帳號（免費帳號也可用於開發）
- 後端 API 的 URL 需要確保在 iOS 設備上可訪問（使用實際 IP 地址而非 localhost）

