-- 診斷和修復用戶註冊問題
-- 執行此腳本來診斷問題並修復

-- ============================================
-- 步驟 1: 檢查現有設置
-- ============================================
-- 檢查 RLS 政策
SELECT 
  'RLS Policies:' as check_type,
  policyname,
  cmd,
  with_check
FROM pg_policies 
WHERE tablename = 'users' AND cmd = 'INSERT';

-- 檢查 Trigger
SELECT 
  'Triggers:' as check_type,
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';

-- 檢查函數
SELECT 
  'Functions:' as check_type,
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines
WHERE routine_name = 'handle_new_user';

-- ============================================
-- 步驟 2: 刪除舊的設置（如果存在）
-- ============================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- ============================================
-- 步驟 3: 創建新的函數和 Trigger
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  user_name TEXT;
  user_role TEXT;
  user_student_id TEXT;
BEGIN
  -- 從 metadata 獲取用戶信息
  user_name := COALESCE(NEW.raw_user_meta_data->>'name', 'User');
  user_role := COALESCE(NEW.raw_user_meta_data->>'role', 'student');
  user_student_id := NEW.raw_user_meta_data->>'student_id';
  
  -- 插入用戶記錄
  INSERT INTO public.users (id, email, name, role, student_id, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    user_name,
    user_role,
    NULLIF(user_student_id, ''),
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    role = EXCLUDED.role,
    student_id = EXCLUDED.student_id,
    updated_at = NOW();
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- 記錄錯誤但不阻止用戶創建
    RAISE WARNING 'Error in handle_new_user: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- 創建 Trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 步驟 4: 確保 RLS 政策正確
-- ============================================
-- 刪除舊政策
DROP POLICY IF EXISTS "Users can insert own data" ON users;

-- 創建新政策
CREATE POLICY "Users can insert own data" ON users
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- ============================================
-- 步驟 5: 測試 Trigger（可選）
-- ============================================
-- 檢查是否有現有用戶沒有對應的記錄
SELECT 
  'Missing user records:' as check_type,
  au.id,
  au.email,
  au.raw_user_meta_data->>'name' as name,
  au.raw_user_meta_data->>'role' as role
FROM auth.users au
LEFT JOIN public.users u ON au.id = u.id
WHERE u.id IS NULL;

-- ============================================
-- 步驟 6: 手動修復現有用戶（如果需要）
-- ============================================
-- 為現有用戶創建記錄（如果他們還沒有）
INSERT INTO public.users (id, email, name, role, student_id, created_at, updated_at)
SELECT 
  au.id,
  au.email,
  COALESCE(au.raw_user_meta_data->>'name', 'User'),
  COALESCE(au.raw_user_meta_data->>'role', 'student'),
  NULLIF(au.raw_user_meta_data->>'student_id', ''),
  au.created_at,
  NOW()
FROM auth.users au
LEFT JOIN public.users u ON au.id = u.id
WHERE u.id IS NULL
ON CONFLICT (id) DO NOTHING;

