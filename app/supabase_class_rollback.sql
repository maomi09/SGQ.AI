-- =====================================================
-- SGQ.AI 班級系統回滾腳本
-- 用於復原 supabase_class_system.sql 的變更
-- =====================================================

-- 1. 先移除所有依賴 class_id 的 RLS Policies
DROP POLICY IF EXISTS "students can view class topics" ON grammar_topics;
DROP POLICY IF EXISTS "students can update own class_id" ON users;

-- 2. 移除 classes 表的 RLS Policies
DROP POLICY IF EXISTS "teachers can view own classes" ON classes;
DROP POLICY IF EXISTS "teachers can view all classes" ON classes;
DROP POLICY IF EXISTS "students can view joined class" ON classes;
DROP POLICY IF EXISTS "teachers can create classes" ON classes;
DROP POLICY IF EXISTS "teachers can update own classes" ON classes;
DROP POLICY IF EXISTS "teachers can update all classes" ON classes;
DROP POLICY IF EXISTS "teachers can delete own classes" ON classes;
DROP POLICY IF EXISTS "teachers can delete all classes" ON classes;
DROP POLICY IF EXISTS "authenticated users can find class by code" ON classes;

-- 3. 移除 grammar_topics 表的 class_id 欄位
ALTER TABLE grammar_topics DROP COLUMN IF EXISTS class_id;

-- 4. 移除 users 表的 class_id 欄位
ALTER TABLE users DROP COLUMN IF EXISTS class_id;

-- 5. 刪除生成班級代碼的函數
DROP FUNCTION IF EXISTS generate_unique_class_code();

-- 6. 刪除 classes 表
DROP TABLE IF EXISTS classes;

-- 7. 重新載入 Schema
NOTIFY pgrst, 'reload schema';

-- =====================================================
-- 回滾完成
-- =====================================================
