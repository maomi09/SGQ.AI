# 複製此檔為 deploy-params.ps1 後填入你的資料（deploy-params.ps1 勿提交 Git）
# Copy-Item deploy-params.example.ps1 deploy-params.ps1

# EC2 登入帳號@公網 IP（與 api.sagp-qp.com 同一台；目前解析為 3.80.19.9）
$Ec2UserAtHost = "ubuntu@3.80.19.9"

# SSH 金鑰 .pem 完整路徑（AWS 下載的 key pair）
$SshKeyPath = "C:\Users\你的使用者名稱\Downloads\你的金鑰.pem"

# 要使用的子網域（需已在 DNS 指向 EC2 IP）
$ExportDomain = "export.sagp-qp.com"

# 網站檔案在伺服器上的目錄
$RemoteWebRoot = "/var/www/sgq-teacher-export"
