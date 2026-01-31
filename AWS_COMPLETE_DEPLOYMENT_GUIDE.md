# AWS 後端完整部署指南

本指南將帶您完成將 SGQ 後端部署到 AWS EC2 的完整流程。

## 目錄

1. [前置準備](#前置準備)
2. [創建 EC2 實例](#創建-ec2-實例)
3. [連接 EC2 實例](#連接-ec2-實例)
4. [安裝系統依賴](#安裝系統依賴)
5. [上傳後端代碼](#上傳後端代碼)
6. [設置環境變數](#設置環境變數)
7. [部署後端服務](#部署後端服務)
8. [配置 systemd 服務](#配置-systemd-服務)
9. [配置 Nginx 反向代理](#配置-nginx-反向代理)
10. [設置 SSL 證書（可選）](#設置-ssl-證書可選)
11. [配置 AWS 安全組](#配置-aws-安全組)
12. [測試部署](#測試部署)
13. [更新 Flutter App](#更新-flutter-app)
14. [監控和維護](#監控和維護)

---

## 前置準備

### 需要的資訊

- [ ] AWS 帳號
- [ ] 域名（可選，但推薦）
- [ ] OpenAI API Key
- [ ] Supabase URL 和 Keys
- [ ] 郵件服務配置（SMTP 或 SendGrid）

### 檢查清單

- [ ] 已準備好所有 API Keys
- [ ] 已決定使用 EC2 IP 或域名
- [ ] 已準備好 SSH 金鑰對

---

## 創建 EC2 實例

### 步驟 1: 登入 AWS Console

1. 前往 [AWS Console](https://console.aws.amazon.com/)
2. 選擇區域（建議選擇離用戶最近的區域，例如：`ap-northeast-1` 東京）

### 步驟 2: 啟動 EC2 實例

1. 在 AWS Console 中搜尋並進入 **EC2**
2. 點擊 **Launch Instance**（啟動實例）

### 步驟 3: 配置實例

#### 3.1 名稱和標籤
- **Name**: `sgq-backend`（或您喜歡的名稱）

#### 3.2 應用程式和作業系統映像
- **Amazon Machine Image (AMI)**: 選擇 **Ubuntu Server 22.04 LTS**（免費層級）

#### 3.3 實例類型
- **Instance type**: 
  - 開發/測試：`t2.micro`（免費層級）
  - 生產環境：`t3.small` 或更高（建議至少 2GB RAM）

#### 3.4 金鑰對（登入）
- **Key pair name**: 選擇現有金鑰對或創建新的
- **Key pair type**: RSA
- **Private key file format**: `.pem`
- **下載金鑰對**並妥善保管（這是唯一一次可以下載）

#### 3.5 網路設定
- **VPC**: 使用預設 VPC
- **Subnet**: 使用預設子網路
- **Auto-assign Public IP**: 啟用
- **Security group**: 創建新的安全組
  - **Security group name**: `sgq-backend-sg`
  - **Description**: `Security group for SGQ backend API`
  - **Inbound rules**:
    - **SSH (22)**: 來源 `My IP`（僅允許您的 IP）
    - **HTTP (80)**: 來源 `0.0.0.0/0`（允許所有 IP）
    - **HTTPS (443)**: 來源 `0.0.0.0/0`（允許所有 IP）
    - **Custom TCP (8000)**: 來源 `0.0.0.0/0`（如果直接使用端口 8000）

#### 3.6 配置儲存
- **Volume size**: 8 GB（免費層級）或更大
- **Volume type**: gp3

#### 3.7 進階詳細資訊（可選）
- 可以在這裡設置 IAM 角色、用戶數據腳本等

### 步驟 4: 啟動實例

1. 點擊 **Launch Instance**
2. 等待實例狀態變為 **Running**
3. 記錄 **Public IPv4 address**（例如：`13.219.229.38`）

---

## 連接 EC2 實例

### Windows (PowerShell)

```powershell
# 確保金鑰檔案權限正確（僅需執行一次）
icacls.exe your-key.pem /inheritance:r
icacls.exe your-key.pem /grant:r "%username%:R"

# 連接到 EC2
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### macOS/Linux

```bash
# 設置金鑰檔案權限（僅需執行一次）
chmod 400 your-key.pem

# 連接到 EC2
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### 首次連接

首次連接時會看到類似訊息：
```
The authenticity of host 'xxx.xxx.xxx.xxx' can't be established.
Are you sure you want to continue connecting (yes/no)?
```
輸入 `yes` 並按 Enter。

---

## 安裝系統依賴

連接到 EC2 後，執行以下命令：

```bash
# 更新系統套件
sudo apt update && sudo apt upgrade -y

# 安裝 Python 3.10 和相關工具
sudo apt install python3.10 python3.10-venv python3-pip -y

# 安裝 Git（如果需要從 Git 倉庫拉取代碼）
sudo apt install git -y

# 安裝 Nginx（用於反向代理，可選但推薦）
sudo apt install nginx -y

# 安裝其他有用的工具
sudo apt install curl wget nano -y

# 驗證 Python 版本
python3 --version
# 應該顯示：Python 3.10.x
```

---

## 上傳後端代碼

### 方式 A: 使用 Git（推薦）

```bash
# 創建專案目錄
cd ~
mkdir -p sgq-backend
cd sgq-backend

# 如果您的代碼在 Git 倉庫中
git clone your-repository-url .
cd backend

# 或者直接從本地複製 backend 資料夾
```

### 方式 B: 使用 SCP（從本地電腦上傳）

在**本地電腦**的終端機執行：

#### Windows (PowerShell)

```powershell
# 上傳整個 backend 資料夾
scp -i your-key.pem -r backend ubuntu@your-ec2-ip:~/
```

#### macOS/Linux

```bash
# 上傳整個 backend 資料夾
scp -i your-key.pem -r backend ubuntu@your-ec2-ip:~/
```

然後在 EC2 上：

```bash
# 移動到正確位置
cd ~
mv backend sgq-backend/backend
cd sgq-backend/backend
```

### 方式 C: 使用 AWS CodeDeploy 或其他 CI/CD 工具

（根據您的 CI/CD 設定進行）

---

## 設置環境變數

### 步驟 1: 創建 .env 檔案

```bash
cd ~/sgq-backend/backend
nano .env
```

### 步驟 2: 填入環境變數

複製以下內容並填入實際值：

```env
# OpenAI API Key（必須）
OPENAI_API_KEY=sk-your-openai-api-key-here

# Supabase 設定（必須）
SUPABASE_URL=https://iqmhqdkpultzyzurolwv.supabase.co
SUPABASE_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

# CORS 設定（可選，生產環境建議限制）
# 多個來源用逗號分隔，例如：https://app.example.com,https://www.example.com
# 留空或設為 * 表示允許所有來源
ALLOWED_ORIGINS=*

# 郵件服務設定（選擇一個）
# 選項 1: SMTP
SMTP_ENABLED=true
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password
SMTP_FROM_EMAIL=your_email@gmail.com

# 選項 2: SendGrid
# SENDGRID_ENABLED=true
# SENDGRID_API_KEY=your_sendgrid_api_key
```

### 步驟 3: 保存並退出

- 按 `Ctrl + O` 保存
- 按 `Enter` 確認
- 按 `Ctrl + X` 退出

### 步驟 4: 驗證檔案權限

```bash
# 確保 .env 檔案只有擁有者可以讀取
chmod 600 .env

# 驗證內容（不顯示敏感資訊）
cat .env | grep -v "KEY\|PASSWORD" | head -5
```

---

## 部署後端服務

### 步驟 1: 執行部署腳本

```bash
cd ~/sgq-backend/backend

# 給腳本執行權限
chmod +x aws_deploy.sh

# 執行部署
./aws_deploy.sh
```

部署腳本會：
- 創建 Python 虛擬環境
- 安裝所有依賴
- 驗證環境變數

### 步驟 2: 手動測試啟動

```bash
# 啟動虛擬環境
source venv/bin/activate

# 測試啟動服務
uvicorn main:app --host 0.0.0.0 --port 8000
```

您應該看到類似輸出：
```
INFO:     Started server process [xxxx]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

### 步驟 3: 測試 API

在**另一個終端機**（或瀏覽器）中：

```bash
# 測試健康檢查端點（如果有的話）
curl http://your-ec2-ip:8000/docs

# 或直接在瀏覽器訪問
# http://your-ec2-ip:8000/docs
```

如果看到 FastAPI 文檔頁面，表示服務運行正常。

按 `Ctrl + C` 停止測試服務。

---

## 配置 systemd 服務

### 步驟 1: 創建服務文件

```bash
cd ~/sgq-backend/backend

# 複製服務文件到 systemd 目錄
sudo cp sgq-backend.service /etc/systemd/system/

# 編輯服務文件，更新路徑
sudo nano /etc/systemd/system/sgq-backend.service
```

### 步驟 2: 更新服務文件

確保以下路徑正確：

```ini
WorkingDirectory=/home/ubuntu/sgq-backend/backend
ExecStart=/home/ubuntu/sgq-backend/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

根據您的實例大小調整 `--workers` 參數：
- 小型實例（1-2 CPU）：`--workers 2`
- 中型實例（2-4 CPU）：`--workers 4`
- 大型實例（4+ CPU）：`--workers 8`

### 步驟 3: 設置環境變數（方法 A：在服務文件中）

在服務文件中添加：

```ini
Environment="OPENAI_API_KEY=your_key_here"
Environment="SUPABASE_URL=your_url_here"
# ... 其他環境變數
```

**注意**：這種方式會將敏感資訊暴露在系統文件中，不推薦用於生產環境。

### 步驟 4: 設置環境變數（方法 B：使用 .env 檔案，推薦）

修改服務文件，讓它從 .env 檔案讀取：

```ini
EnvironmentFile=/home/ubuntu/sgq-backend/backend/.env
```

然後在服務文件中移除具體的環境變數設定。

### 步驟 5: 啟用並啟動服務

```bash
# 重新載入 systemd
sudo systemctl daemon-reload

# 啟用開機自啟
sudo systemctl enable sgq-backend

# 啟動服務
sudo systemctl start sgq-backend

# 檢查服務狀態
sudo systemctl status sgq-backend
```

您應該看到 `Active: active (running)`。

### 步驟 6: 查看日誌

```bash
# 查看即時日誌
sudo journalctl -u sgq-backend -f

# 查看最近的日誌
sudo journalctl -u sgq-backend -n 50

# 查看錯誤日誌
sudo journalctl -u sgq-backend -p err
```

---

## 配置 Nginx 反向代理

### 步驟 1: 創建 Nginx 配置

```bash
cd ~/sgq-backend/backend

# 複製配置範例
sudo cp nginx.conf.example /etc/nginx/sites-available/sgq-backend

# 編輯配置
sudo nano /etc/nginx/sites-available/sgq-backend
```

### 步驟 2: 更新配置

#### 如果使用 IP 地址：

```nginx
server {
    listen 80;
    server_name your-ec2-ip;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

#### 如果使用域名：

```nginx
server {
    listen 80;
    server_name api.your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### 步驟 3: 啟用配置

```bash
# 創建符號連結
sudo ln -s /etc/nginx/sites-available/sgq-backend /etc/nginx/sites-enabled/

# 測試配置
sudo nginx -t

# 如果測試通過，重啟 Nginx
sudo systemctl restart nginx

# 檢查 Nginx 狀態
sudo systemctl status nginx
```

### 步驟 4: 測試訪問

```bash
# 測試通過 Nginx 訪問
curl http://your-ec2-ip/

# 或
curl http://api.your-domain.com/
```

---

## 設置 SSL 證書（可選）

### 使用 Let's Encrypt（免費）

### 步驟 1: 安裝 Certbot

```bash
sudo apt install certbot python3-certbot-nginx -y
```

### 步驟 2: 獲取 SSL 證書

```bash
# 如果使用域名
sudo certbot --nginx -d api.your-domain.com

# 如果有多個域名
sudo certbot --nginx -d api.your-domain.com -d www.api.your-domain.com
```

Certbot 會：
- 自動配置 Nginx
- 設置自動續期
- 重定向 HTTP 到 HTTPS

### 步驟 3: 測試自動續期

```bash
# 測試續期（不會實際續期）
sudo certbot renew --dry-run
```

### 步驟 4: 驗證 HTTPS

```bash
# 測試 HTTPS 連接
curl https://api.your-domain.com/docs
```

---

## 配置 AWS 安全組

### 步驟 1: 進入安全組設定

1. 在 AWS Console → EC2 → Instances
2. 選擇您的實例
3. 點擊 **Security** 標籤
4. 點擊安全組名稱

### 步驟 2: 檢查入站規則

確保有以下規則：

| 類型 | 協議 | 端口範圍 | 來源 | 說明 |
|------|------|----------|------|------|
| SSH | TCP | 22 | My IP | 僅允許您的 IP |
| HTTP | TCP | 80 | 0.0.0.0/0 | 允許所有 HTTP |
| HTTPS | TCP | 443 | 0.0.0.0/0 | 允許所有 HTTPS |
| Custom TCP | TCP | 8000 | 0.0.0.0/0 | 如果直接使用端口 8000 |

### 步驟 3: 編輯入站規則（如果需要）

1. 點擊 **Edit inbound rules**
2. 添加或修改規則
3. 點擊 **Save rules**

---

## 測試部署

### 步驟 1: 測試 API 端點

```bash
# 測試健康檢查（如果有的話）
curl http://your-ec2-ip:8000/

# 測試 API 文檔
curl http://your-ec2-ip:8000/docs

# 如果使用 Nginx
curl http://your-ec2-ip/docs
curl http://api.your-domain.com/docs
```

### 步驟 2: 測試 ChatGPT 端點

```bash
curl -X POST http://your-ec2-ip:8000/api/chatgpt \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello"}],
    "student_id": "test-student-id"
  }'
```

### 步驟 3: 檢查服務狀態

```bash
# 檢查 systemd 服務
sudo systemctl status sgq-backend

# 檢查 Nginx
sudo systemctl status nginx

# 檢查端口監聽
sudo netstat -tulpn | grep 8000
sudo netstat -tulpn | grep 80
```

### 步驟 4: 查看日誌

```bash
# 後端服務日誌
sudo journalctl -u sgq-backend -n 50

# Nginx 訪問日誌
sudo tail -f /var/log/nginx/access.log

# Nginx 錯誤日誌
sudo tail -f /var/log/nginx/error.log
```

---

## 更新 Flutter App

### 步驟 1: 打開配置檔案

在本地電腦上，打開：
```
app/lib/config/app_config.dart
```

### 步驟 2: 更新後端 URL

#### 選項 A: 使用 EC2 IP（開發/測試）

```dart
// 使用 EC2 公共 IP
static const String backendApiUrl = 'http://13.219.229.38:8000';
```

#### 選項 B: 使用域名（生產環境，推薦）

```dart
// 使用域名
static const String backendApiUrl = 'https://api.your-domain.com';
```

#### 選項 C: 使用 Nginx（如果配置了 Nginx）

```dart
// 通過 Nginx 訪問（端口 80）
static const String backendApiUrl = 'http://your-ec2-ip';

// 或使用域名
static const String backendApiUrl = 'https://api.your-domain.com';
```

### 步驟 3: 重新編譯 App

```bash
cd app
flutter clean
flutter pub get
flutter build apk  # Android
# 或
flutter build ios  # iOS
```

### 步驟 4: 測試連接

1. 安裝 App 到設備
2. 嘗試使用需要後端 API 的功能
3. 檢查控制台日誌，確認連接成功

---

## 監控和維護

### 日常監控

#### 查看服務狀態

```bash
# 後端服務狀態
sudo systemctl status sgq-backend

# Nginx 狀態
sudo systemctl status nginx
```

#### 查看日誌

```bash
# 後端服務日誌
sudo journalctl -u sgq-backend -f

# Nginx 訪問日誌
sudo tail -f /var/log/nginx/access.log

# Nginx 錯誤日誌
sudo tail -f /var/log/nginx/error.log
```

#### 檢查資源使用

```bash
# CPU 和記憶體使用
htop
# 或
top

# 磁碟使用
df -h

# 網路連接
sudo netstat -tulpn
```

### 常見維護操作

#### 重啟服務

```bash
# 重啟後端服務
sudo systemctl restart sgq-backend

# 重啟 Nginx
sudo systemctl restart nginx
```

#### 更新代碼

```bash
cd ~/sgq-backend/backend

# 如果使用 Git
git pull

# 更新依賴
source venv/bin/activate
pip install -r requirements.txt

# 重啟服務
sudo systemctl restart sgq-backend
```

#### 更新環境變數

```bash
cd ~/sgq-backend/backend
nano .env
# 修改後重啟服務
sudo systemctl restart sgq-backend
```

### 備份

#### 備份環境變數

```bash
# 備份 .env 檔案
cp ~/sgq-backend/backend/.env ~/sgq-backend/backend/.env.backup.$(date +%Y%m%d)
```

#### 備份代碼

建議使用 Git 進行版本控制。

### 故障排除

#### 服務無法啟動

1. 檢查日誌：`sudo journalctl -u sgq-backend -n 50`
2. 檢查環境變數：`cat ~/sgq-backend/backend/.env`
3. 檢查 Python 版本：`python3 --version`
4. 手動測試：`source venv/bin/activate && uvicorn main:app --host 0.0.0.0 --port 8000`

#### 無法從外部訪問

1. 檢查安全組設定
2. 檢查防火牆：`sudo ufw status`
3. 檢查服務是否運行：`sudo systemctl status sgq-backend`
4. 檢查端口監聽：`sudo netstat -tulpn | grep 8000`

#### API 響應慢

1. 增加 worker 數量（在服務文件中）
2. 檢查 EC2 實例的 CPU 和記憶體使用率
3. 考慮使用更大的實例類型
4. 檢查 OpenAI API 響應時間

---

## 安全建議

1. **定期更新系統**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **設置防火牆**
   ```bash
   sudo ufw enable
   sudo ufw allow 22/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```

3. **限制 SSH 訪問**
   - 僅允許特定 IP 訪問 SSH（在安全組中設置）

4. **使用 HTTPS**
   - 生產環境必須使用 HTTPS

5. **定期備份**
   - 備份環境變數和配置檔案

6. **監控日誌**
   - 定期檢查日誌，發現異常活動

---

## 完成檢查清單

- [ ] EC2 實例已創建並運行
- [ ] 已連接到 EC2 實例
- [ ] 系統依賴已安裝
- [ ] 後端代碼已上傳
- [ ] 環境變數已設置
- [ ] 後端服務已部署
- [ ] systemd 服務已配置並運行
- [ ] Nginx 已配置（可選）
- [ ] SSL 證書已設置（可選）
- [ ] AWS 安全組已配置
- [ ] API 測試通過
- [ ] Flutter App 已更新配置
- [ ] App 連接測試成功

---

## 需要幫助？

如果遇到問題，請檢查：

1. **服務日誌**：`sudo journalctl -u sgq-backend -n 100`
2. **Nginx 日誌**：`sudo tail -f /var/log/nginx/error.log`
3. **系統日誌**：`sudo dmesg | tail`
4. **AWS CloudWatch**：在 AWS Console 中查看實例日誌

---

**部署完成！** 🎉

您的後端現在應該已經在 AWS 上運行。記得定期監控和維護服務。
