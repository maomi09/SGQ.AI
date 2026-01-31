# AWS 後端部署完整指南

## 前置需求

1. AWS EC2 實例（建議使用 Ubuntu 22.04 LTS）
2. 已配置的安全組（允許 HTTP/HTTPS 流量）
3. 域名（可選，但推薦）

## 部署步驟

### 步驟 1: 連接到 EC2 實例

```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### 步驟 2: 安裝系統依賴

```bash
# 更新系統
sudo apt update && sudo apt upgrade -y

# 安裝 Python 3.10 和 pip
sudo apt install python3.10 python3.10-venv python3-pip -y

# 安裝 Nginx（用於反向代理，可選）
sudo apt install nginx -y
```

### 步驟 3: 上傳後端代碼

有幾種方式可以上傳代碼：

**方式 A: 使用 Git（推薦）**
```bash
cd ~
git clone your-repository-url sgq-backend
cd sgq-backend/backend
```

**方式 B: 使用 SCP**
```bash
# 在本地執行
scp -i your-key.pem -r backend/ ubuntu@your-ec2-ip:~/
ssh -i your-key.pem ubuntu@your-ec2-ip
cd ~/backend
```

**方式 C: 使用 AWS CodeDeploy 或其他 CI/CD 工具**

### 步驟 4: 設置環境變數

創建 `.env` 檔案：

```bash
cd ~/sgq-backend/backend
nano .env
```

添加以下內容：

```env
# OpenAI API Key（必須）
OPENAI_API_KEY=your_openai_api_key_here

# Supabase 設定（必須）
SUPABASE_URL=https://iqmhqdkpultzyzurolwv.supabase.co
SUPABASE_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

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

### 步驟 5: 部署後端

```bash
# 執行部署腳本
chmod +x aws_deploy.sh
./aws_deploy.sh
```

### 步驟 6: 測試啟動

```bash
# 手動啟動測試
source venv/bin/activate
uvicorn main:app --host 0.0.0.0 --port 8000
```

在瀏覽器中訪問 `http://your-ec2-ip:8000/docs` 確認 API 文檔可以訪問。

### 步驟 7: 設置 systemd 服務（推薦）

```bash
# 複製服務文件
sudo cp sgq-backend.service /etc/systemd/system/

# 編輯服務文件，更新路徑和環境變數
sudo nano /etc/systemd/system/sgq-backend.service

# 重新載入 systemd
sudo systemctl daemon-reload

# 啟動服務
sudo systemctl start sgq-backend

# 設置開機自啟
sudo systemctl enable sgq-backend

# 檢查服務狀態
sudo systemctl status sgq-backend
```

### 步驟 8: 配置 Nginx 反向代理（可選但推薦）

```bash
# 複製 Nginx 配置
sudo cp nginx.conf.example /etc/nginx/sites-available/sgq-backend

# 編輯配置，更新域名
sudo nano /etc/nginx/sites-available/sgq-backend

# 創建符號連結
sudo ln -s /etc/nginx/sites-available/sgq-backend /etc/nginx/sites-enabled/

# 測試 Nginx 配置
sudo nginx -t

# 重啟 Nginx
sudo systemctl restart nginx
```

### 步驟 9: 設置 SSL 證書（可選但推薦）

```bash
# 安裝 Certbot
sudo apt install certbot python3-certbot-nginx -y

# 獲取 SSL 證書
sudo certbot --nginx -d your-domain.com -d api.your-domain.com

# 自動續期（Certbot 會自動設置）
```

### 步驟 10: 配置安全組

在 AWS Console → EC2 → Security Groups：

1. 允許 HTTP (端口 80) - 來源: 0.0.0.0/0
2. 允許 HTTPS (端口 443) - 來源: 0.0.0.0/0
3. 如果直接使用端口 8000，允許 TCP (端口 8000) - 來源: 0.0.0.0/0

### 步驟 11: 更新 Flutter App 配置

在 `app/lib/config/app_config.dart` 中更新：

```dart
// 使用 EC2 IP
static const String backendApiUrl = 'http://your-ec2-ip:8000';

// 或使用域名（推薦）
static const String backendApiUrl = 'https://api.your-domain.com';
```

## 監控和日誌

### 查看服務日誌

```bash
# systemd 服務日誌
sudo journalctl -u sgq-backend -f

# 或查看最近的日誌
sudo journalctl -u sgq-backend -n 100
```

### 重啟服務

```bash
sudo systemctl restart sgq-backend
```

### 停止服務

```bash
sudo systemctl stop sgq-backend
```

## 性能優化

### 調整 Worker 數量

在 `sgq-backend.service` 中調整 `--workers` 參數：

- 小型實例（1-2 CPU）：`--workers 2`
- 中型實例（2-4 CPU）：`--workers 4`
- 大型實例（4+ CPU）：`--workers 8`

### 使用 Gunicorn（替代方案）

如果需要更進階的配置，可以使用 Gunicorn：

```bash
pip install gunicorn

# 創建 gunicorn_config.py
```

## 故障排除

### 服務無法啟動

1. 檢查日誌：`sudo journalctl -u sgq-backend -n 50`
2. 檢查環境變數是否正確設置
3. 檢查端口是否被占用：`sudo netstat -tulpn | grep 8000`

### 無法從外部訪問

1. 檢查安全組設定
2. 檢查防火牆：`sudo ufw status`
3. 檢查服務是否運行：`sudo systemctl status sgq-backend`

### API 響應慢

1. 增加 worker 數量
2. 檢查 EC2 實例的 CPU 和記憶體使用率
3. 考慮使用更大的實例類型

## 備份和恢復

### 備份環境變數

```bash
# 備份 .env 檔案
cp .env .env.backup
```

### 備份代碼

建議使用 Git 進行版本控制。

## 安全建議

1. **不要將 `.env` 檔案提交到 Git**
2. **使用 IAM 角色而不是硬編碼 AWS 憑證**
3. **定期更新依賴**：`pip install --upgrade -r requirements.txt`
4. **設置防火牆規則**：只允許必要的端口
5. **使用 HTTPS**：保護 API 通信
6. **定期檢查日誌**：監控異常活動

## 更新部署

當需要更新代碼時：

```bash
cd ~/sgq-backend/backend
git pull  # 或上傳新代碼
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart sgq-backend
```

## 聯繫支援

如果遇到問題，請檢查：
1. 服務日誌
2. Nginx 日誌（如果使用）：`sudo tail -f /var/log/nginx/error.log`
3. 系統日誌：`sudo dmesg | tail`
