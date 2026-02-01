# 正式上線 APP 後端 URL 配置指南

## 問題：正式上線 APP 可以使用 EC2 IP 當作後端 URL 嗎？

**簡短答案**：技術上可行，但**不建議**用於正式上線的生產環境。

---

## 使用 EC2 IP 的限制

### 1. IP 地址可能變更

- 當您停止或重啟 EC2 實例時，公共 IP 地址可能會改變
- 除非使用 **Elastic IP**，否則 IP 不是固定的
- 如果 IP 改變，所有用戶的 App 將無法連接到後端

### 2. 無法使用 HTTPS（SSL 證書）

- SSL 證書需要域名，無法為 IP 地址頒發證書
- **iOS App Store 要求使用 HTTPS**
- 沒有 HTTPS 會導致安全問題和合規問題

### 3. 專業度和維護性

- 使用 IP 地址看起來不專業
- 難以擴展（負載平衡、多實例等）
- 不便於遷移或更換主機

---

## 建議方案

### 方案 A：使用 Elastic IP + 域名 + HTTPS（強烈推薦）

這是最佳實踐，適合正式上線的生產環境。

#### 步驟 1：申請 Elastic IP（固定 IP）

在 AWS Console 中：

1. 前往 **EC2 → Elastic IPs**
2. 點擊 **Allocate Elastic IP address**
3. 選擇 **Amazon's pool of IPv4 addresses**
4. 點擊 **Allocate**
5. 選擇剛申請的 Elastic IP
6. 點擊 **Actions → Associate Elastic IP address**
7. 選擇您的 EC2 實例
8. 點擊 **Associate**

**注意**：
- Elastic IP 在實例運行時是**免費**的
- 如果實例停止，會收取約 $0.005/小時的費用

#### 步驟 2：設置域名

1. **購買域名**（如果還沒有）
   - 推薦服務商：GoDaddy、Namecheap、AWS Route 53
   - 價格：約 $10-15/年

2. **設置 DNS A 記錄**
   - 登入您的域名註冊商或 DNS 服務商
   - 添加 A 記錄：
     - **名稱**：`api`（或 `backend`）
     - **類型**：A
     - **值**：您的 Elastic IP（例如：`13.219.229.38`）
     - **TTL**：300（或使用預設值）
   - 例如：`api.yourdomain.com` → `13.219.229.38`

3. **等待 DNS 傳播**
   - 通常需要 5 分鐘到 48 小時
   - 可以使用 `dig api.yourdomain.com` 或 `nslookup api.yourdomain.com` 檢查

#### 步驟 3：設置 SSL 證書（Let's Encrypt 免費）

在 EC2 上執行：

```bash
# 安裝 Certbot
sudo apt update
sudo apt install certbot python3-certbot-nginx -y

# 獲取 SSL 證書（替換為您的域名）
sudo certbot --nginx -d api.yourdomain.com

# 按照提示輸入：
# - 電子郵件地址（用於續期通知）
# - 同意服務條款
# - 是否重定向 HTTP 到 HTTPS（建議選擇 Yes）
```

Certbot 會：
- 自動獲取 SSL 證書
- 自動配置 Nginx
- 設置自動續期（證書每 90 天自動更新）

**測試自動續期**：

```bash
sudo certbot renew --dry-run
```

#### 步驟 4：驗證 HTTPS

```bash
# 測試 HTTPS 連接
curl https://api.yourdomain.com/

# 應該看到：{"message":"SGQ API Server"}
```

#### 步驟 5：更新 Flutter App 配置

打開 `app/lib/config/app_config.dart`：

```dart
// 正式上線：使用域名和 HTTPS
static const String backendApiUrl = 'https://api.yourdomain.com';
```

#### 步驟 6：重新編譯 App

```bash
cd app
flutter clean
flutter pub get
flutter build apk  # Android
# 或
flutter build ios  # iOS
```

---

### 方案 B：暫時使用 Elastic IP（過渡方案）

如果暫時無法設置域名，至少使用 Elastic IP 來固定 IP 地址。

#### 步驟 1：申請 Elastic IP

（同方案 A 的步驟 1）

#### 步驟 2：更新 Flutter App 配置

```dart
// 暫時使用（不推薦長期使用）
static const String backendApiUrl = 'http://your-elastic-ip';
```

**注意**：
- 此方案仍無法使用 HTTPS
- 可能不符合 App Store 要求
- 僅適合作為過渡方案

---

## App Store 要求

### iOS App Store

- **要求使用 HTTPS**（ATS - App Transport Security）
- 使用 HTTP 的 App 可能被拒絕上架
- 必須使用有效的 SSL 證書

### Google Play Store

- **強烈建議使用 HTTPS**
- 使用 HTTP 的 App 可能被標記為不安全
- 可能影響用戶信任度

---

## 成本估算

| 項目 | 成本 |
|------|------|
| Elastic IP | 實例運行時免費；停止時約 $0.005/小時 |
| 域名 | 約 $10-15/年 |
| SSL 證書（Let's Encrypt） | 免費 |
| **總計** | **約 $10-15/年** |

---

## 快速檢查清單

正式上線前，請確認：

- [ ] 已申請 Elastic IP 並關聯到 EC2 實例
- [ ] 已購買並設置域名
- [ ] DNS A 記錄已正確指向 Elastic IP
- [ ] 已安裝並配置 SSL 證書（HTTPS）
- [ ] Nginx 配置已更新並啟用 HTTPS
- [ ] Flutter App 配置已更新為 HTTPS URL
- [ ] 已測試所有 API 功能
- [ ] 已確認 App Store 合規性

---

## 驗證步驟

### 1. 檢查 Elastic IP

在 AWS Console：
- EC2 → Elastic IPs
- 確認 Elastic IP 已關聯到您的實例

### 2. 檢查 DNS 解析

```bash
# 在本地電腦執行
nslookup api.yourdomain.com
# 或
dig api.yourdomain.com
```

應該返回您的 Elastic IP。

### 3. 檢查 HTTPS

```bash
# 測試 HTTPS 連接
curl https://api.yourdomain.com/

# 檢查 SSL 證書
openssl s_client -connect api.yourdomain.com:443 -servername api.yourdomain.com
```

### 4. 檢查 Nginx 配置

```bash
# 在 EC2 上執行
sudo nginx -t
sudo systemctl status nginx
```

### 5. 測試 Flutter App

1. 更新 `app_config.dart` 為 HTTPS URL
2. 重新編譯 App
3. 安裝到設備並測試所有功能
4. 確認所有 API 請求都使用 HTTPS

---

## 常見問題

### Q: 如果我的 EC2 實例停止，Elastic IP 會怎樣？

A: Elastic IP 會保留，但會收取約 $0.005/小時的費用。建議在不需要時釋放 Elastic IP，或保持實例運行。

### Q: DNS 傳播需要多長時間？

A: 通常 5 分鐘到 48 小時，但大多數情況下在 1 小時內完成。

### Q: Let's Encrypt 證書會過期嗎？

A: 證書有效期為 90 天，但 Certbot 會自動續期。只要 Certbot 正常運行，證書不會過期。

### Q: 可以為多個域名設置 SSL 嗎？

A: 可以。在 `certbot` 命令中添加多個 `-d` 參數：

```bash
sudo certbot --nginx -d api.yourdomain.com -d www.api.yourdomain.com
```

### Q: 如果我的域名還沒準備好，可以先上線嗎？

A: 不建議。App Store 要求 HTTPS，沒有域名就無法設置 SSL 證書。建議先完成域名和 SSL 設置再上線。

---

## 總結

**正式上線的 APP 應該使用**：

1. ✅ **Elastic IP**（固定 IP）
2. ✅ **域名**（專業、易維護）
3. ✅ **HTTPS**（安全、符合規範）

**不建議使用**：

1. ❌ 臨時 EC2 IP（可能變更）
2. ❌ HTTP（不安全、不符合規範）
3. ❌ 直接使用 IP 地址（不專業）

---

## 需要幫助？

如果遇到問題，請檢查：

1. **Elastic IP 狀態**：AWS Console → EC2 → Elastic IPs
2. **DNS 解析**：使用 `nslookup` 或 `dig` 命令
3. **SSL 證書**：`sudo certbot certificates`
4. **Nginx 日誌**：`sudo tail -f /var/log/nginx/error.log`
5. **後端服務**：`sudo systemctl status sgq-backend`

---

**部署完成後，您的後端將具備**：

- ✅ 固定的 IP 地址（Elastic IP）
- ✅ 專業的域名
- ✅ 安全的 HTTPS 連接
- ✅ 符合 App Store 要求
- ✅ 易於維護和擴展
