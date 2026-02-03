-- ============================================
-- Supabase Realtime 和 RLS 政策檢查腳本
-- ============================================

-- ============================================
-- 步驟 1: 檢查 Realtime 是否已啟用
-- ============================================

-- 1.1 檢查 Realtime 擴展是否已安裝
SELECT 
  extname as extension_name,
  extversion as version
FROM pg_extension
WHERE extname = 'pg_catalog';

-- 1.2 檢查 Realtime 是否啟用（需要查看 publication）
-- 注意：Supabase 使用 publication 來控制哪些表可以通過 Realtime 訂閱
SELECT 
  pubname as publication_name,
  puballtables as all_tables
FROM pg_publication
WHERE pubname = 'supabase_realtime';

-- 1.3 檢查哪些表被添加到 Realtime publication
SELECT 
  schemaname,
  tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY schemaname, tablename;

-- ============================================
-- 步驟 2: 啟用 Realtime（如果未啟用）
-- ============================================

-- 2.1 將 grammar_topics 表添加到 Realtime publication
-- 注意：如果表不在列表中，執行以下命令
-- ALTER PUBLICATION supabase_realtime ADD TABLE grammar_topics;

-- 2.2 將 questions 表添加到 Realtime publication
-- ALTER PUBLICATION supabase_realtime ADD TABLE questions;

-- 2.3 將 badges 表添加到 Realtime publication
-- ALTER PUBLICATION supabase_realtime ADD TABLE badges;

-- ============================================
-- 步驟 3: 檢查 RLS 政策是否允許學生訂閱
-- ============================================

-- 3.1 檢查 grammar_topics 表的 RLS 政策
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  qual as using_condition,
  with_check as with_check_condition
FROM pg_policies
WHERE tablename = 'grammar_topics'
ORDER BY cmd, policyname;

-- 3.2 檢查 questions 表的 RLS 政策
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  qual as using_condition,
  with_check as with_check_condition
FROM pg_policies
WHERE tablename = 'questions'
ORDER BY cmd, policyname;

-- 3.3 檢查 badges 表的 RLS 政策
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  qual as using_condition,
  with_check as with_check_condition
FROM pg_policies
WHERE tablename = 'badges'
ORDER BY cmd, policyname;

-- ============================================
-- 步驟 4: 檢查學生是否有 SELECT 權限
-- ============================================

-- 4.1 檢查 grammar_topics 的 SELECT 政策（學生應該可以讀取所有課程）
-- 應該有一個政策允許所有用戶（包括學生）SELECT grammar_topics
SELECT 
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'grammar_topics' 
  AND cmd = 'SELECT';

-- 4.2 檢查 questions 的 SELECT 政策（學生應該只能讀取自己的題目）
-- 應該有一個政策允許學生 SELECT 自己的 questions
SELECT 
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'questions' 
  AND cmd = 'SELECT';

-- 4.3 檢查 badges 的 SELECT 政策（學生應該只能讀取自己的徽章）
-- 應該有一個政策允許學生 SELECT 自己的 badges
SELECT 
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'badges' 
  AND cmd = 'SELECT';

-- ============================================
-- 步驟 5: 測試查詢（模擬學生查詢）
-- ============================================

-- 5.1 測試查詢 grammar_topics（應該返回所有課程）
-- SELECT * FROM grammar_topics LIMIT 5;

-- 5.2 測試查詢 questions（需要替換為實際的學生 ID）
-- SELECT * FROM questions WHERE student_id = 'YOUR_STUDENT_ID' LIMIT 5;

-- 5.3 測試查詢 badges（需要替換為實際的學生 ID）
-- SELECT * FROM badges WHERE student_id = 'YOUR_STUDENT_ID' LIMIT 5;
