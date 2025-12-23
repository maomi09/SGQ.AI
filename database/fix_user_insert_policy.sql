-- 修復用戶插入記錄的 RLS 政策
-- 執行此腳本來修復 Row Level Security 政策，允許用戶在註冊時插入自己的記錄

-- 刪除現有的插入政策（如果存在）
DROP POLICY IF EXISTS "Users can insert own data" ON users;

-- 創建新的插入政策，確保用戶可以插入自己的記錄
-- 使用 SECURITY DEFINER 或確保政策正確檢查 auth.uid()
CREATE POLICY "Users can insert own data" ON users
  FOR INSERT 
  WITH CHECK (
    -- 用戶可以插入自己的記錄（id 必須等於 auth.uid()）
    auth.uid() = id
  );

-- 驗證政策已創建
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
WHERE tablename = 'users' AND policyname = 'Users can insert own data';

