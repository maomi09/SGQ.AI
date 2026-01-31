#!/bin/bash
# AWS 後端部署腳本
# 用於在 EC2 實例上部署 FastAPI 後端

set -e

echo "開始部署 SGQ 後端到 AWS..."

# 檢查 Python 版本
python3 --version

# 創建虛擬環境（如果不存在）
if [ ! -d "venv" ]; then
    echo "創建 Python 虛擬環境..."
    python3 -m venv venv
fi

# 啟動虛擬環境
echo "啟動虛擬環境..."
source venv/bin/activate

# 升級 pip
echo "升級 pip..."
pip install --upgrade pip

# 安裝依賴
echo "安裝依賴..."
pip install -r requirements.txt

# 檢查 .env 檔案
if [ ! -f ".env" ]; then
    echo "警告: .env 檔案不存在，請確保已設置環境變數"
    echo "需要的環境變數："
    echo "  - OPENAI_API_KEY"
    echo "  - SUPABASE_URL"
    echo "  - SUPABASE_KEY"
    echo "  - SUPABASE_SERVICE_ROLE_KEY"
    echo "  - SMTP_ENABLED 或 SENDGRID_ENABLED"
fi

echo "部署完成！"
echo "使用以下命令啟動服務："
echo "  source venv/bin/activate"
echo "  uvicorn main:app --host 0.0.0.0 --port 8000"
