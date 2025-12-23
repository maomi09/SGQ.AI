-- 允許匿名用戶檢查信箱是否已被使用
-- 方案 1: 創建一個安全的數據庫函數來檢查信箱（推薦）

-- 創建函數來檢查信箱是否已被使用
CREATE OR REPLACE FUNCTION public.check_email_availability(check_email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- 檢查 users 表中是否存在該信箱
  RETURN EXISTS (
    SELECT 1 
    FROM public.users 
    WHERE LOWER(TRIM(email)) = LOWER(TRIM(check_email))
    AND email IS NOT NULL
    AND email != ''
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 允許匿名用戶執行此函數
GRANT EXECUTE ON FUNCTION public.check_email_availability(TEXT) TO anon, authenticated;

-- 方案 2: 如果不想使用函數，可以使用 RLS 政策（較不安全）
-- 刪除舊政策（如果存在）
DROP POLICY IF EXISTS "Anyone can check email availability" ON users;

-- 創建新政策：允許任何人（包括未登入用戶）查詢 email 欄位來檢查信箱是否已被使用
-- 注意：這個政策會暴露所有用戶的 email，如果擔心隱私，請使用上面的函數方案
CREATE POLICY "Anyone can check email availability" ON users
  FOR SELECT 
  USING (true);

