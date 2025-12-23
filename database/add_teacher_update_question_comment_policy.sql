-- 允許老師更新學生題目的評語字段
-- 執行此腳本來添加老師更新題目評語的 RLS 政策

-- ============================================
-- 步驟 1: 刪除舊的政策（如果存在）
-- ============================================
DROP POLICY IF EXISTS "Teachers can update question comments" ON questions;

-- ============================================
-- 步驟 2: 創建新的政策
-- ============================================
-- 允許老師更新所有學生題目的評語字段
CREATE POLICY "Teachers can update question comments" ON questions
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'teacher'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'teacher'
    )
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
WHERE tablename = 'questions'
ORDER BY policyname;

