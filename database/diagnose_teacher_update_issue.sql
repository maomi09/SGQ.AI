-- 診斷老師更新學生資料的問題
-- 在 Supabase Dashboard > SQL Editor 中執行此腳本來診斷問題

-- ============================================
-- 步驟 1: 檢查現有的 UPDATE 政策
-- ============================================
SELECT 
  policyname,
  cmd,
  qual as using_condition,
  with_check as with_check_condition
FROM pg_policies
WHERE tablename = 'users' 
  AND cmd = 'UPDATE'
ORDER BY policyname;

-- ============================================
-- 步驟 2: 檢查老師帳號的 auth metadata
-- ============================================
-- 檢查所有老師帳號的 raw_user_meta_data 中是否有 role
SELECT 
  au.id,
  au.email,
  au.raw_user_meta_data->>'role' as role_from_metadata,
  pu.role as role_from_users_table,
  au.raw_user_meta_data
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.role = 'teacher'
ORDER BY au.created_at DESC;

-- ============================================
-- 步驟 3: 檢查是否有老師帳號缺少 role metadata
-- ============================================
SELECT 
  au.id,
  au.email,
  au.raw_user_meta_data->>'role' as role_from_metadata,
  pu.role as role_from_users_table
FROM auth.users au
INNER JOIN public.users pu ON au.id = pu.id
WHERE pu.role = 'teacher'
  AND (au.raw_user_meta_data->>'role' IS NULL 
       OR au.raw_user_meta_data->>'role' != 'teacher');

-- ============================================
-- 步驟 4: 修復缺少 role metadata 的老師帳號
-- ============================================
-- 執行此腳本來更新所有老師帳號的 metadata
UPDATE auth.users
SET raw_user_meta_data = jsonb_set(
  COALESCE(raw_user_meta_data, '{}'::jsonb),
  '{role}',
  '"teacher"'
)
WHERE id IN (
  SELECT id FROM public.users WHERE role = 'teacher'
)
AND (raw_user_meta_data->>'role' IS NULL 
     OR raw_user_meta_data->>'role' != 'teacher');

-- ============================================
-- 步驟 5: 檢查政策是否使用正確的方式檢查 role
-- ============================================
-- 查看 "Teachers can update students" 政策的詳細內容
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'users' 
  AND policyname = 'Teachers can update students';

-- ============================================
-- 步驟 6: 測試 JWT token 中的 role（需要在應用程式中執行）
-- ============================================
-- 注意：此查詢需要在應用程式中執行，因為需要 auth.uid()
-- 在 Flutter 應用程式中，可以執行：
-- SELECT auth.jwt() -> 'user_metadata' ->> 'role' as current_user_role;

-- ============================================
-- 步驟 7: 檢查是否有其他 UPDATE 政策衝突
-- ============================================
-- 查看所有 UPDATE 政策，確認是否有衝突
SELECT 
  policyname,
  permissive,  -- PERMISSIVE 或 RESTRICTIVE
  roles,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'users' 
  AND cmd = 'UPDATE'
ORDER BY policyname;
