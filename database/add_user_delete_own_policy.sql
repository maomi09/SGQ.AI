-- 允許使用者刪除自己在 public.users 的記錄（用於 App 內「刪除帳號」功能）
-- 若沒有此政策，RLS 會阻擋刪除，導致 public.users 中該帳號仍存在。
-- 執行方式：Supabase Dashboard > SQL Editor > 貼上此腳本 > Run

DROP POLICY IF EXISTS "Users can delete own data" ON users;

CREATE POLICY "Users can delete own data" ON users
  FOR DELETE
  USING (auth.uid() = id);

-- 驗證：查詢 users 表目前的 DELETE 相關政策
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'users' AND cmd = 'DELETE';
