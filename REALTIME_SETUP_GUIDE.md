# Supabase Realtime 設定檢查指南

本指南將幫助您檢查和設定 Supabase Realtime，確保學生端能夠即時接收通知。

## 檢查步驟

### 步驟 1: 檢查 Supabase Realtime 是否已啟用

#### 方法 A: 使用 Supabase Dashboard

1. **登入 Supabase Dashboard**
   - 前往 [https://supabase.com/dashboard](https://supabase.com/dashboard)
   - 選擇您的專案

2. **檢查 Database 設定**
   - 在左側選單中，點擊 **Database** > **Replication**
   - 查看是否有 `supabase_realtime` publication

3. **檢查表是否已添加到 Realtime**
   - 在 Replication 頁面中，查看哪些表已啟用 Realtime
   - 確認以下表已啟用：
     - `grammar_topics`
     - `questions`
     - `badges`

#### 方法 B: 使用 SQL Editor

1. **打開 SQL Editor**
   - 在 Supabase Dashboard 中，點擊左側選單的 **SQL Editor**
   - 點擊 **New query**

2. **執行檢查查詢**
   ```sql
   -- 檢查哪些表已添加到 Realtime publication
   SELECT 
     schemaname,
     tablename
   FROM pg_publication_tables
   WHERE pubname = 'supabase_realtime'
   ORDER BY schemaname, tablename;
   ```

3. **如果表未列出，執行啟用腳本**
   - 複製 `database/enable_realtime_tables.sql` 的內容
   - 在 SQL Editor 中執行

---

### 步驟 2: 檢查 RLS 政策是否允許學生訂閱

#### 方法 A: 使用 Supabase Dashboard

1. **查看 RLS 政策**
   - 在左側選單中，點擊 **Table Editor**
   - 選擇 `grammar_topics` 表
   - 點擊 **Policies** 標籤
   - 重複此步驟檢查 `questions` 和 `badges` 表

2. **確認必要的政策存在**

   **grammar_topics 表：**
   - 應該有一個 SELECT 政策，允許所有用戶（包括學生）讀取所有課程
   - 例如：`SELECT` 政策，USING 條件為 `true` 或沒有條件

   **questions 表：**
   - 應該有一個 SELECT 政策，允許學生讀取自己的題目
   - 例如：`SELECT` 政策，USING 條件為 `auth.uid() = student_id`

   **badges 表：**
   - 應該有一個 SELECT 政策，允許學生讀取自己的徽章
   - 例如：`SELECT` 政策，USING 條件為 `auth.uid() = student_id`

#### 方法 B: 使用 SQL Editor

1. **執行檢查查詢**
   ```sql
   -- 檢查 grammar_topics 的 RLS 政策
   SELECT 
     tablename,
     policyname,
     cmd,
     qual as using_condition
   FROM pg_policies
   WHERE tablename = 'grammar_topics' 
     AND cmd = 'SELECT';
   
   -- 檢查 questions 的 RLS 政策
   SELECT 
     tablename,
     policyname,
     cmd,
     qual as using_condition
   FROM pg_policies
   WHERE tablename = 'questions' 
     AND cmd = 'SELECT';
   
   -- 檢查 badges 的 RLS 政策
   SELECT 
     tablename,
     policyname,
     cmd,
     qual as using_condition
   FROM pg_policies
   WHERE tablename = 'badges' 
     AND cmd = 'SELECT';
   ```

2. **如果缺少政策，創建它們**

   **為 grammar_topics 創建 SELECT 政策（如果不存在）：**
   ```sql
   CREATE POLICY "Students can read all grammar topics"
   ON grammar_topics
   FOR SELECT
   USING (true);
   ```

   **為 questions 創建 SELECT 政策（如果不存在）：**
   ```sql
   CREATE POLICY "Students can read own questions"
   ON questions
   FOR SELECT
   USING (auth.uid() = student_id);
   ```

   **為 badges 創建 SELECT 政策（如果不存在）：**
   ```sql
   CREATE POLICY "Students can read own badges"
   ON badges
   FOR SELECT
   USING (auth.uid() = student_id);
   ```

---

### 步驟 3: 檢查網路連接

#### 方法 A: 在 Flutter 應用中檢查

1. **查看應用日誌**
   - 運行 Flutter 應用
   - 查看控制台輸出
   - 尋找以下訊息：
     - `Realtime 訂閱成功：已連接到 grammar_topics 表`
     - `Realtime 訂閱成功：已連接到 questions 表（評語）`
     - `Realtime 訂閱成功：已連接到 badges 表`

2. **檢查錯誤訊息**
   - 如果看到以下錯誤，表示連接有問題：
     - `Realtime 訂閱超時`
     - `Realtime 訂閱錯誤`
     - `初始化 Realtime 訂閱失敗`

#### 方法 B: 檢查 Supabase 連接設定

1. **檢查 AppConfig**
   - 打開 `app/lib/config/app_config.dart`
   - 確認 `supabaseUrl` 和 `supabaseAnonKey` 正確設定

2. **測試 Supabase 連接**
   ```dart
   // 在 Flutter 應用中添加測試代碼
   final client = Supabase.instance.client;
   print('Supabase URL: ${client.supabaseUrl}');
   print('Current User: ${client.auth.currentUser?.id}');
   ```

#### 方法 C: 使用瀏覽器檢查

1. **檢查 Supabase Realtime 端點**
   - 打開瀏覽器開發者工具（F12）
   - 前往 Network 標籤
   - 運行 Flutter 應用
   - 查找 WebSocket 連接（通常以 `wss://` 開頭）
   - 確認連接到 Supabase Realtime 端點

---

## 快速檢查清單

- [ ] Realtime publication 包含 `grammar_topics` 表
- [ ] Realtime publication 包含 `questions` 表
- [ ] Realtime publication 包含 `badges` 表
- [ ] `grammar_topics` 表有 SELECT RLS 政策（允許所有用戶讀取）
- [ ] `questions` 表有 SELECT RLS 政策（允許學生讀取自己的題目）
- [ ] `badges` 表有 SELECT RLS 政策（允許學生讀取自己的徽章）
- [ ] Flutter 應用日誌顯示 "Realtime 訂閱成功" 訊息
- [ ] 沒有 Realtime 連接錯誤

---

## 常見問題排除

### 問題 1: Realtime 訂閱超時

**可能原因：**
- 表未添加到 Realtime publication
- 網路連接問題
- Supabase 專案設定問題

**解決方法：**
1. 執行 `database/enable_realtime_tables.sql`
2. 檢查網路連接
3. 確認 Supabase 專案狀態正常

### 問題 2: 收到 "權限被拒絕" 錯誤

**可能原因：**
- RLS 政策不允許學生讀取表
- 學生未登入或 session 過期

**解決方法：**
1. 檢查並創建必要的 RLS 政策
2. 確認學生已正確登入
3. 檢查 `auth.uid()` 是否正確返回學生 ID

### 問題 3: 通知未即時顯示

**可能原因：**
- Realtime 訂閱未正確建立
- 通知去重邏輯過於嚴格
- 應用未在前台運行

**解決方法：**
1. 檢查應用日誌，確認訂閱狀態
2. 清除 SharedPreferences 中的通知記錄
3. 確認應用有通知權限

---

## 執行檢查腳本

您可以使用 `database/check_realtime_setup.sql` 來一次性檢查所有設定：

1. 在 Supabase Dashboard 中打開 SQL Editor
2. 複製 `database/check_realtime_setup.sql` 的內容
3. 執行查詢
4. 根據結果修復問題

---

## 需要幫助？

如果問題仍然存在，請提供：
1. Supabase Dashboard 中 Realtime 設定的截圖
2. RLS 政策的查詢結果
3. Flutter 應用的完整錯誤日誌
