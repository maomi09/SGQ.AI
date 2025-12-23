-- 修復 RLS 政策無限遞迴問題
-- 執行此腳本來修復 Row Level Security 政策的無限遞迴問題

-- 刪除有問題的政策（如果存在）
DROP POLICY IF EXISTS "Teachers can read all students" ON users;

-- 創建新的政策，避免無限遞迴
-- 使用 auth.jwt() 直接從 JWT token 中獲取 role，而不是查詢 users 表
CREATE POLICY "Teachers can read all students" ON users
  FOR SELECT USING (
    -- 直接從 JWT token 中獲取 role，避免查詢 users 表
    (auth.jwt() ->> 'user_metadata')::jsonb ->> 'role' = 'teacher'
    OR
    -- 或者用戶可以讀取自己的資料
    auth.uid() = id
  );

