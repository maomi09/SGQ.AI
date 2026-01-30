# AWS 後端設置指南

## 已完成的工作

已將 Flutter App 的後端 URL 配置統一改為使用 AWS 後端。所有相關檔案都已更新為使用 `AppConfig.backendApiUrl`。

## 設置步驟

### 1. 修改後端 URL

打開 `app/lib/config/app_config.dart`，將 `backendApiUrl` 改為您的 AWS 後端地址：

```dart
// 生產環境：AWS 後端 URL
static const String backendApiUrl = 'https://your-aws-backend-url.com';
```

**選項 A：使用 EC2 公共 IP**
```dart
static const String backendApiUrl = 'http://your-ec2-public-ip';
```

**選項 B：使用域名（推薦）**
```dart
static const String backendApiUrl = 'https://api.yourdomain.com';
```

**選項 C：使用 Elastic Beanstalk URL**
```dart
static const String backendApiUrl = 'http://your-app.region.elasticbeanstalk.com';
```

### 2. 確保 AWS 後端已正確設置

- [ ] 後端服務已在 AWS 上運行
- [ ] 安全組已允許來自網際網路的 HTTP/HTTPS 請求
- [ ] 如果使用 HTTPS，SSL 證書已配置
- [ ] 環境變數（OPENAI_API_KEY、SUPABASE_URL 等）已在 AWS 上設置

### 3. 測試連接

在 Flutter App 中測試後端連接：
1. 運行應用程式
2. 嘗試使用需要後端 API 的功能（例如：註冊、ChatGPT 對話等）
3. 檢查控制台日誌，確認連接成功

## 本地開發模式

如果需要切換回本地開發環境，可以：

1. 在 `app/lib/config/app_config.dart` 中修改：
```dart
static const String backendApiUrl = 'http://localhost:8000';
```

2. 或者在相關服務檔案中取消註釋本地開發的程式碼（已保留在註釋中）

## 修改的檔案

以下檔案已更新為使用統一的 `AppConfig.backendApiUrl`：

1. `app/lib/config/app_config.dart` - 主要配置檔案
2. `app/lib/services/supabase_service.dart` - Supabase 服務
3. `app/lib/services/chatgpt_service.dart` - ChatGPT 服務
4. `app/lib/screens/report_bug_screen.dart` - 錯誤回報頁面

## 注意事項

1. **HTTPS 要求**：如果您的 AWS 後端使用 HTTPS，請確保 URL 以 `https://` 開頭
2. **CORS 設定**：確保 AWS 後端的 CORS 設定允許來自 Flutter App 的請求
3. **安全組**：確保 AWS 安全組允許來自網際網路的連接
4. **測試**：在部署到生產環境前，請先在測試環境中驗證所有功能

## 常見問題

### Q: 如何找到我的 EC2 公共 IP？
A: 在 AWS Console → EC2 → Instances，選擇您的實例，在詳細資訊中查看 "Public IPv4 address"

### Q: 如何設置域名？
A: 
1. 在 Route 53 或其他 DNS 服務商設置 A 記錄指向您的 EC2 IP
2. 在 EC2 上設置 Nginx 反向代理
3. 使用 Let's Encrypt 設置 SSL 證書

### Q: 連接失敗怎麼辦？
A: 
1. 檢查 AWS 安全組設定
2. 檢查後端服務是否正在運行
3. 檢查防火牆設定
4. 查看後端日誌（Supervisor 或 Nginx 日誌）
