# SGQ 學習系統 - 設定指南

## 前置需求

1. Flutter SDK (3.10.1 或更高版本)
2. Python 3.10 或更高版本
3. Supabase 帳號
4. OpenAI API Key

## 設定步驟

### 步驟 1: Supabase 設定

1. 登入 Supabase 並建立新專案
2. 在專案的 SQL Editor 中執行 `database/schema.sql`
3. 在專案設定中取得：
   - Project URL
   - Anon/Public Key

### 步驟 2: Flutter 應用程式設定

1. 開啟 `app/lib/main.dart`
2. 更新 Supabase 設定：
```dart
await Supabase.initialize(
  url: '你的_SUPABASE_URL',
  anonKey: '你的_SUPABASE_ANON_KEY',
);
```

3. 開啟 `app/lib/services/chatgpt_service.dart`
4. 更新 ChatGPT API Key：
```dart
final chatGPTService = ChatGPTService(
  apiKey: '你的_OPENAI_API_KEY',
);
```

5. 安裝依賴：
```bash
cd app
flutter pub get
```

### 步驟 3: 後端 API 設定

1. 進入 `backend` 目錄
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
SUPABASE_URL=你的_SUPABASE_URL
SUPABASE_KEY=你的_SUPABASE_KEY
OPENAI_API_KEY=你的_OPENAI_API_KEY
```

6. 啟動伺服器：
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 步驟 4: 執行應用程式

1. 確保後端 API 正在運行
2. 在 `app` 目錄執行：
```bash
flutter run
```

## 測試帳號

建議先建立測試帳號：
- 老師帳號：用於建立課程和查看統計
- 學生帳號：用於測試學生端功能

## 常見問題

### 1. Supabase 連線錯誤
- 確認 URL 和 Key 是否正確
- 確認資料表是否已建立
- 檢查 RLS 政策設定

### 2. ChatGPT API 錯誤
- 確認 API Key 是否有效
- 確認帳號有足夠的額度

### 3. 後端 API 無法連線
- 確認伺服器是否正在運行
- 檢查防火牆設定
- 確認端口是否被占用

## 下一步

1. 根據需求調整 UI 設計
2. 自訂徽章系統規則
3. 調整 ChatGPT prompt 以符合教學需求
4. 設定適當的 RLS 政策以確保資料安全

