-- 允許老師讀取所有學生的題目
-- 執行此腳本來添加老師讀取學生題目的 RLS 政策

-- ============================================
-- 步驟 1: 刪除舊的政策（如果存在）
-- ============================================
DROP POLICY IF EXISTS "Teachers can read all student questions" ON questions;

-- ============================================
-- 步驟 2: 創建新的政策
-- ============================================
-- 允許老師讀取所有學生的題目
CREATE POLICY "Teachers can read all student questions" ON questions
  FOR SELECT USING (
    -- 從 JWT token 中獲取 role（如果 metadata 中有）
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'teacher'
    OR
    -- 或者學生可以讀取自己的題目
    auth.uid() = student_id
  );

-- ============================================
-- 驗證政策已創建
-- ============================================
-- 查詢所有 questions 表的政策
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
WHERE tablename = 'questions';

