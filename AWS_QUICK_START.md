# AWS 部署快速開始指南

這是一個簡化版的快速開始指南，適合有經驗的開發者。詳細步驟請參考 `AWS_COMPLETE_DEPLOYMENT_GUIDE.md`。

## 快速檢查清單

### 1. 創建 EC2 實例
- [ ] Ubuntu 22.04 LTS
- [ ] t2.micro 或更高
- [ ] 安全組：SSH (22), HTTP (80), HTTPS (443), Custom TCP (8000)

### 2. 連接並設置

```bash
# 連接 EC2
ssh -i your-key.pem ubuntu@your-ec2-ip

# 安裝依賴
sudo apt update && sudo apt upgrade -y
sudo apt install python3.10 python3.10-venv python3-pip nginx git -y

# 上傳代碼（使用 SCP 或 Git）
# 方式 A: SCP
# 在本地執行: scp -i your-key.pem -r backend ubuntu@your-ec2-ip:~/

# 方式 B: Git
cd ~
git clone your-repo-url sgq-backend
cd sgq-backend/backend
```

### 3. 配置環境變數

```bash
nano .env
# 填入所有必要的環境變數
chmod 600 .env
```

### 4. 部署

```bash
chmod +x aws_deploy.sh
./aws_deploy.sh
```

### 5. 設置 systemd 服務

```bash
sudo cp sgq-backend.service /etc/systemd/system/
sudo nano /etc/systemd/system/sgq-backend.service  # 確認路徑正確
sudo systemctl daemon-reload
sudo systemctl enable sgq-backend
sudo systemctl start sgq-backend
sudo systemctl status sgq-backend
```

### 6. 配置 Nginx（可選）

```bash
sudo cp nginx.conf.example /etc/nginx/sites-available/sgq-backend
sudo nano /etc/nginx/sites-available/sgq-backend  # 更新域名/IP
sudo ln -s /etc/nginx/sites-available/sgq-backend /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 7. 設置 SSL（可選）

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d api.your-domain.com
```

### 8. 更新 Flutter App

在 `app/lib/config/app_config.dart` 中：

```dart
static const String backendApiUrl = 'http://your-ec2-ip:8000';
// 或
static const String backendApiUrl = 'https://api.your-domain.com';
```

## 常用命令

```bash
# 查看服務狀態
sudo systemctl status sgq-backend

# 查看日誌
sudo journalctl -u sgq-backend -f

# 重啟服務
sudo systemctl restart sgq-backend

# 更新代碼
cd ~/sgq-backend/backend
git pull  # 或上傳新代碼
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart sgq-backend
```

## 測試

```bash
# 測試 API
curl http://your-ec2-ip:8000/docs

# 或通過 Nginx
curl http://your-ec2-ip/docs
```

---

**詳細步驟請參考：`AWS_COMPLETE_DEPLOYMENT_GUIDE.md`**
