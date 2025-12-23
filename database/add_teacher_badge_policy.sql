-- 添加教師授予徽章的 RLS 政策
-- 執行此腳本來允許教師為學生授予徽章

-- ============================================
-- 步驟 1: 刪除舊的政策（如果存在）
-- ============================================
DROP POLICY IF EXISTS "Students can read own badges" ON badges;
DROP POLICY IF EXISTS "Teachers can award badges" ON badges;

-- ============================================
-- 步驟 2: 學生可以讀取自己的徽章
-- ============================================
CREATE POLICY "Students can read own badges" ON badges
  FOR SELECT USING (auth.uid() = student_id);

-- ============================================
-- 步驟 3: 教師可以為學生授予徽章（INSERT）
-- ============================================
CREATE POLICY "Teachers can award badges" ON badges
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'teacher'
    )
  );

-- ============================================
-- 步驟 4: 教師可以讀取所有學生的徽章（SELECT）
-- ============================================
CREATE POLICY "Teachers can read all badges" ON badges
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'teacher'
    )
  );

