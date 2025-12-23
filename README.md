# SGQ 學習系統

這是一個支援大學EFL學生進行學生生成文法問題(SGQ)活動的教育應用程式。

## 專案結構

```
AI-APP-FINAL/
├── app/                    # Flutter 應用程式
│   ├── lib/
│   │   ├── models/        # 資料模型
│   │   ├── services/      # 服務層（Supabase、ChatGPT）
│   │   ├── providers/     # 狀態管理
│   │   ├── screens/       # UI 頁面
│   │   └── main.dart      # 應用程式入口
│   └── pubspec.yaml       # Flutter 依賴
├── backend/               # 後端 API (FastAPI)
│   ├── main.py           # API 主程式
│   └── requirements.txt  # Python 依賴
└── database/             # 資料庫架構
    └── schema.sql        # Supabase 資料表定義
```

## 功能特色

### 學生端
- **文法重點**：查看老師設定的文法重點
- **出題重點提醒**：查看出題時的注意事項
- **出題區**：建立選擇題或問答題
- **個人**：查看個人資料
- **ChatGPT 輔助**：四個階段的鷹架式引導
- **徽章系統**：完成題目後獲得徽章

### 老師端
- **課程管理**：建立和管理文法主題、文法重點、出題重點提醒
- **儀錶板**：查看學生進度，識別需要協助的學生
- **數據統計**：查看學生使用統計（登入頻率、使用時長、練習題數等）
- **個人**：查看個人資料

## 設定步驟

### 1. Flutter 應用程式設定

1. 進入 `app` 目錄：
```bash
cd app
```

2. 安裝依賴：
```bash
flutter pub get
```

3. 設定 Supabase：
   - 在 `lib/main.dart` 中更新 Supabase URL 和 Anon Key
   - 在 Supabase 專案中執行 `database/schema.sql` 建立資料表

4. 設定 ChatGPT API Key：
   - 在 `lib/services/chatgpt_service.dart` 中更新 API Key
   - 或使用環境變數（需要額外設定）

### 2. 後端 API 設定

1. 進入 `backend` 目錄：
```bash
cd backend
```

2. 建立虛擬環境：
```bash
python -m venv venv
```

3. 啟動虛擬環境：
```bash
# Windows
venv\Scripts\activate

# macOS/Linux
source venv/bin/activate
```

4. 安裝依賴：
```bash
pip install -r requirements.txt
```

5. 建立 `.env` 檔案：
```
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key
OPENAI_API_KEY=your_openai_api_key
```

6. 啟動伺服器：
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 3. 資料庫設定

1. 在 Supabase 專案中開啟 SQL Editor
2. 執行 `database/schema.sql` 中的 SQL 語句
3. 確認 Row Level Security (RLS) 政策已正確設定

## 執行應用程式

### Flutter 應用程式
```bash
cd app
flutter run
```

### 後端 API
```bash
cd backend
uvicorn main:app --reload
```

## 技術棧

- **前端**：Flutter (iOS + Android)
- **後端**：FastAPI (Python)
- **資料庫**：Supabase (PostgreSQL)
- **AI 服務**：OpenAI ChatGPT API
- **狀態管理**：Provider

## 注意事項

1. 請確保已設定 Supabase 專案並取得 URL 和 Anon Key
2. 請確保已取得 OpenAI API Key
3. 後端 API 需要與 Flutter 應用程式在同一網路或使用公開 URL
4. 資料庫 RLS 政策需要根據實際需求調整

## 授權

此專案為教育用途。

