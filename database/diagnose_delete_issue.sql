-- 診斷刪除課程問題
-- 執行此腳本來檢查 RLS 政策和權限設置

-- ============================================
-- 步驟 1: 檢查 grammar_topics 表的 RLS 政策
-- ============================================
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'grammar_topics'
ORDER BY policyname;

-- ============================================
-- 步驟 2: 檢查是否有 DELETE 政策
-- ============================================
SELECT 
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'grammar_topics' 
  AND cmd = 'DELETE';

-- ============================================
-- 步驟 3: 檢查所有相關表的外鍵約束
-- ============================================
SELECT
  tc.table_name, 
  kcu.column_name, 
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name,
  rc.delete_rule
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints AS rc
  ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND ccu.table_name = 'grammar_topics'
ORDER BY tc.table_name;

-- ============================================
-- 步驟 4: 檢查當前用戶（需要在應用中執行，這裡只是範例）
-- ============================================
-- 在 Supabase Dashboard 的 SQL Editor 中，以當前登入用戶身份執行：
-- SELECT auth.uid() as current_user_id;
-- SELECT * FROM users WHERE id = auth.uid();

-- ============================================
-- 步驟 5: 測試刪除權限（手動測試）
-- ============================================
-- 在應用中嘗試刪除課程後，執行以下查詢檢查課程是否真的被刪除：
-- SELECT id, title, teacher_id, created_at 
-- FROM grammar_topics 
-- ORDER BY created_at DESC 
-- LIMIT 10;

