-- 檢查老師權限的 SQL 腳本
-- 在 Supabase Dashboard > SQL Editor 中執行此腳本來檢查權限

-- ============================================
-- 1. 檢查 users 表的所有 RLS 政策
-- ============================================
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,  -- SELECT, INSERT, UPDATE, DELETE
  qual,  -- USING 條件
  with_check  -- WITH CHECK 條件
FROM pg_policies
WHERE tablename = 'users'
ORDER BY cmd, policyname;

-- ============================================
-- 2. 檢查是否有老師更新學生的政策
-- ============================================
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'users' 
  AND cmd = 'UPDATE'
  AND (policyname LIKE '%teacher%' OR policyname LIKE '%Teacher%');

-- ============================================
-- 3. 檢查當前用戶的 role（需要在應用程式中執行）
-- ============================================
-- 注意：此查詢需要在應用程式中執行，因為需要 auth.uid()
SELECT 
  id,
  email,
  name,
  role,
  (SELECT role FROM users WHERE id = auth.uid()) as current_user_role
FROM users
WHERE id = auth.uid();

-- ============================================
-- 4. 檢查所有老師帳號
-- ============================================
SELECT 
  id,
  email,
  name,
  role,
  created_at
FROM users
WHERE role = 'teacher'
ORDER BY created_at DESC;

-- ============================================
-- 5. 檢查 auth.users 中的 role metadata
-- ============================================
SELECT 
  id,
  email,
  raw_user_meta_data->>'role' as role_from_metadata,
  raw_user_meta_data
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'teacher'
LIMIT 10;

-- ============================================
-- 6. 測試更新權限（需要在應用程式中執行）
-- ============================================
-- 注意：此查詢需要在應用程式中執行，因為需要 auth.uid()
-- 嘗試更新一個學生的資料來測試權限
-- UPDATE users 
-- SET name = name  -- 不實際改變，只是測試
-- WHERE role = 'student' 
-- LIMIT 1;
