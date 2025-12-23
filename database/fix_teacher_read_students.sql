-- 修復老師讀取學生資料的 RLS 政策
-- 執行此腳本來修復老師無法讀取學生資料的問題

-- ============================================
-- 步驟 1: 更新所有老師帳號的 auth metadata
-- ============================================
-- 確保所有老師帳號的 role 都在 auth.users 的 raw_user_meta_data 中
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
-- 步驟 2: 更新所有學生帳號的 auth metadata
-- ============================================
-- 確保所有學生帳號的 role 都在 auth.users 的 raw_user_meta_data 中
UPDATE auth.users
SET raw_user_meta_data = jsonb_set(
  COALESCE(raw_user_meta_data, '{}'::jsonb),
  '{role}',
  '"student"'
)
WHERE id IN (
  SELECT id FROM public.users WHERE role = 'student'
);

-- ============================================
-- 步驟 3: 刪除舊的 RLS 政策（如果存在）
-- ============================================
DROP POLICY IF EXISTS "Teachers can read all students" ON users;

-- ============================================
-- 步驟 4: 創建新的 RLS 政策
-- ============================================
-- 使用 JWT token 中的 metadata 來判斷是否為老師
CREATE POLICY "Teachers can read all students" ON users
  FOR SELECT USING (
    -- 從 JWT token 中獲取 role（如果 metadata 中有）
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'teacher'
    OR
    -- 或者用戶可以讀取自己的資料
    auth.uid() = id
  );

-- ============================================
-- 步驟 5: 創建 SECURITY DEFINER 函數作為備用方案
-- ============================================
-- 如果上面的政策不工作，可以使用這個函數來繞過 RLS
CREATE OR REPLACE FUNCTION public.get_all_students()
RETURNS TABLE (
  id UUID,
  email TEXT,
  name TEXT,
  role TEXT,
  student_id TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.email,
    u.name,
    u.role,
    u.student_id,
    u.created_at
  FROM users u
  WHERE u.role = 'student';
END;
$$;

-- 授予函數執行權限給 authenticated 用戶
GRANT EXECUTE ON FUNCTION public.get_all_students() TO authenticated;

-- ============================================
-- 步驟 6: 驗證設置
-- ============================================
-- 檢查 RLS 政策
SELECT 
  'RLS Policy Check' as check_type,
  policyname,
  cmd,
  with_check
FROM pg_policies 
WHERE tablename = 'users' AND policyname = 'Teachers can read all students';

-- 檢查函數
SELECT 
  'Function Check' as check_type,
  routine_name,
  security_type
FROM information_schema.routines
WHERE routine_name = 'get_all_students';

-- 檢查學生數量
SELECT 
  'Student Count' as check_type,
  COUNT(*) as student_count
FROM users 
WHERE role = 'student';

