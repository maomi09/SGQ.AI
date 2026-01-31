-- 修復老師更新學生資料的 RLS 政策
-- 如果現有政策不工作，執行此腳本來重新創建政策

-- ============================================
-- 步驟 1: 確保所有老師帳號的 metadata 中有 role
-- ============================================
-- 更新所有老師帳號的 auth.users.raw_user_meta_data
UPDATE auth.users
SET raw_user_meta_data = jsonb_set(
  COALESCE(raw_user_meta_data, '{}'::jsonb),
  '{role}',
  '"teacher"'
)
WHERE id IN (
  SELECT id FROM public.users WHERE role = 'teacher'
);

-- ============================================
-- 步驟 2: 刪除舊的政策（如果存在）
-- ============================================
DROP POLICY IF EXISTS "Teachers can update students" ON users;

-- ============================================
-- 步驟 3: 創建新的政策（使用 auth.jwt()）
-- ============================================
-- 方案 A: 使用 auth.jwt() 從 JWT token 中獲取 role（推薦）
CREATE POLICY "Teachers can update students" ON users
  FOR UPDATE
  USING (
    -- 從 JWT token 中獲取 role
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

-- ============================================
-- 步驟 4: 如果方案 A 不工作，嘗試使用 SECURITY DEFINER 函數
-- ============================================
-- 如果上面的政策仍然不工作，可以使用這個函數來繞過 RLS
CREATE OR REPLACE FUNCTION public.update_student_by_teacher(
  student_id UUID,
  new_name TEXT DEFAULT NULL,
  new_email TEXT DEFAULT NULL,
  new_student_id TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_user_role TEXT;
BEGIN
  -- 檢查當前用戶是否為老師
  SELECT role INTO current_user_role
  FROM users
  WHERE id = auth.uid();
  
  IF current_user_role != 'teacher' THEN
    RAISE EXCEPTION '只有老師可以更新學生資料';
  END IF;
  
  -- 更新學生資料
  UPDATE users
  SET 
    name = COALESCE(new_name, name),
    email = COALESCE(new_email, email),
    student_id = COALESCE(new_student_id, student_id),
    updated_at = NOW()
  WHERE id = student_id
    AND role = 'student';
    
  IF NOT FOUND THEN
    RAISE EXCEPTION '找不到指定的學生或該帳號不是學生';
  END IF;
END;
$$;

-- 授予執行權限給所有已認證的用戶
GRANT EXECUTE ON FUNCTION public.update_student_by_teacher TO authenticated;

-- ============================================
-- 步驟 5: 驗證政策已創建
-- ============================================
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'users' 
  AND policyname = 'Teachers can update students';

-- ============================================
-- 注意事項
-- ============================================
-- 1. 執行此腳本後，請重新登入應用程式以刷新 JWT token
-- 2. 如果使用 SECURITY DEFINER 函數，需要在應用程式中調用此函數而不是直接 UPDATE
-- 3. 確保所有老師帳號的 raw_user_meta_data 中有 role = 'teacher'
