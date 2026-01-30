-- 允許老師讀取所有學生的 session 數據（用於統計）
-- 執行此腳本來添加老師讀取學生 session 的 RLS 政策

-- 允許老師讀取所有學生的 session 數據
CREATE POLICY "Teachers can read all student sessions" ON user_sessions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'teacher'
    )
  );
