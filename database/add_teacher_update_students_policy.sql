-- 允許老師更新學生資料的 RLS 政策
-- 執行此腳本來添加老師更新學生資料的權限

-- ============================================
-- 步驟 1: 檢查現有的 UPDATE 政策
-- ============================================
-- 在 Supabase Dashboard > SQL Editor 中執行此查詢來查看現有政策
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
WHERE tablename = 'users' AND cmd = 'UPDATE'
ORDER BY policyname;

-- ============================================
-- 步驟 2: 創建老師更新學生資料的政策
-- ============================================
-- 允許老師更新所有學生的資料（name, email, student_id）
-- 注意：使用 auth.jwt() 來避免無限遞迴問題

-- 方案 A: 使用 auth.jwt() 從 JWT token 中獲取 role（推薦，避免無限遞迴）
CREATE POLICY "Teachers can update students" ON users
  FOR UPDATE
  USING (
    -- 從 JWT token 中獲取 role，避免查詢 users 表
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'teacher'
    OR
    -- 或者用戶可以更新自己的資料
    auth.uid() = id
  )
  WITH CHECK (
    -- 更新後的檢查：確保只能更新學生資料，且當前用戶是老師
    (
      (auth.jwt() -> 'user_metadata' ->> 'role') = 'teacher'
      AND role = 'student'  -- 只能更新學生的資料
    )
    OR
    -- 或者用戶可以更新自己的資料
    auth.uid() = id
  );

-- 方案 B: 如果方案 A 不工作，可以使用查詢 users 表的方式（可能會有無限遞迴問題）
-- 如果遇到無限遞迴，請使用方案 A
/*
CREATE POLICY "Teachers can update students" ON users
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() 
      AND users.role = 'teacher'
    )
    OR auth.uid() = id
  )
  WITH CHECK (
    (
      EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid() 
        AND users.role = 'teacher'
      )
      AND role = 'student'
    )
    OR auth.uid() = id
  );
*/

-- ============================================
-- 步驟 3: 驗證政策已創建
-- ============================================
-- 查詢所有 users 表的 UPDATE 政策
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
WHERE tablename = 'users' AND cmd = 'UPDATE'
ORDER BY policyname;

-- ============================================
-- 注意事項
-- ============================================
-- 1. 此政策允許老師更新所有學生的資料（name, email, student_id）
-- 2. 學生仍然可以更新自己的資料
-- 3. 如果遇到無限遞迴問題，可能需要使用 auth.jwt() 來獲取 role
-- 4. 如果政策不工作，可以嘗試使用 SECURITY DEFINER 函數
