-- 完整的用戶設置腳本
-- 執行此腳本來設置用戶註冊功能
-- 包括：修復 RLS 政策 + 創建自動插入 Trigger

-- ============================================
-- 步驟 1: 修復 RLS 插入政策
-- ============================================
DROP POLICY IF EXISTS "Users can insert own data" ON users;

CREATE POLICY "Users can insert own data" ON users
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- ============================================
-- 步驟 2: 創建自動插入用戶記錄的 Trigger
-- ============================================
-- 這個 Trigger 會在 Supabase Auth 創建新用戶時自動在 users 表中創建對應記錄
-- 使用 SECURITY DEFINER 可以繞過 RLS 政策

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role, student_id)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'student'),
    NEW.raw_user_meta_data->>'student_id'
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    role = EXCLUDED.role,
    student_id = EXCLUDED.student_id,
    updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 刪除舊的 Trigger（如果存在）
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 創建新的 Trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 步驟 3: 驗證設置
-- ============================================
-- 檢查 RLS 政策
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'users' AND cmd = 'INSERT';

-- 檢查 Trigger
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'users' OR trigger_name = 'on_auth_user_created';

