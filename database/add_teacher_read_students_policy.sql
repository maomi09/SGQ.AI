-- 允許老師讀取所有學生資料
-- 執行此腳本來添加老師讀取學生資料的 RLS 政策

-- 允許老師讀取所有學生的資料
CREATE POLICY "Teachers can read all students" ON users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'teacher'
    )
  );

