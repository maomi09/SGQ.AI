-- 修復老師刪除文法主題的 RLS 政策
-- 執行此腳本來確保老師可以刪除文法主題

-- ============================================
-- 步驟 1: 刪除舊的政策（如果存在）
-- ============================================
DROP POLICY IF EXISTS "Teachers can manage grammar topics" ON grammar_topics;
DROP POLICY IF EXISTS "Anyone can read grammar topics" ON grammar_topics;

-- ============================================
-- 步驟 2: 創建新的政策 - 分別為 SELECT, INSERT, UPDATE, DELETE
-- ============================================

-- 所有使用者可以讀取文法主題
CREATE POLICY "Anyone can read grammar topics" ON grammar_topics
  FOR SELECT USING (true);

-- 老師可以插入文法主題
CREATE POLICY "Teachers can insert grammar topics" ON grammar_topics
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'teacher'
    )
  );

-- 老師可以更新文法主題
CREATE POLICY "Teachers can update grammar topics" ON grammar_topics
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'teacher'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'teacher'
    )
  );

-- 老師可以刪除文法主題
CREATE POLICY "Teachers can delete grammar topics" ON grammar_topics
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'teacher'
    )
  );

-- ============================================
-- 驗證政策已創建
-- ============================================
-- 查詢所有 grammar_topics 表的政策
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

