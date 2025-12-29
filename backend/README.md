# SGQ 後端 API

## 安裝

1. 建立虛擬環境：
```bash
python -m venv venv
```

2. 啟動虛擬環境：
```bash
# Windows
venv\Scripts\activate

# macOS/Linux
source venv/bin/activate
```

3. 安裝依賴：
```bash
pip install -r requirements.txt
```

4. 設定環境變數：
   
   複製範本檔案並填入你的設定值：
   ```bash
   # Windows
   copy .env.example .env
   
   # macOS/Linux
   cp .env.example .env
   ```
   
   然後編輯 `.env` 檔案，填入你的實際 API key：
   ```
   OPENAI_API_KEY=your_openai_api_key_here
   SUPABASE_URL=your_supabase_url
   SUPABASE_KEY=your_supabase_key
   ```
   
   **重要**：
   - `OPENAI_API_KEY` 是必須的，否則程式無法啟動
   - 其他環境變數為可選，有預設值
   - 詳細設定說明請參考 `.env.example` 檔案
   - 郵件服務設定請參考 `EMAIL_SETUP_GUIDE.md`

## 執行

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

API 文件可在 `http://localhost:8000/docs` 查看。

by abcs haha.