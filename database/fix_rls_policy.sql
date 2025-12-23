-- 修復 users 表的 RLS 政策
-- 執行此腳本來修復 Row Level Security 政策問題

-- 刪除現有政策（如果存在）
DROP POLICY IF EXISTS "Users can insert own data" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;

-- 允許用戶插入自己的記錄（註冊時使用）
CREATE POLICY "Users can insert own data" ON users
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- 允許用戶更新自己的記錄
CREATE POLICY "Users can update own data" ON users
  FOR UPDATE 
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
