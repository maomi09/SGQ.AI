-- =====================================================
-- SGQ.AI 班級系統資料庫結構
-- 請在 Supabase SQL Editor 執行此腳本
-- =====================================================

-- 1. 建立 classes 表（班級）
CREATE TABLE IF NOT EXISTS classes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    code VARCHAR(6) NOT NULL UNIQUE,
    -- 建立者（保留紀錄用）：共同管理模式下不作為權限限制依據
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 建立 code 索引以加速查詢
CREATE INDEX IF NOT EXISTS idx_classes_code ON classes(code);
CREATE INDEX IF NOT EXISTS idx_classes_teacher_id ON classes(teacher_id);

-- 2. 修改 users 表，新增 class_id 欄位（學生加入的班級）
ALTER TABLE users ADD COLUMN IF NOT EXISTS class_id UUID REFERENCES classes(id) ON DELETE SET NULL;

-- 3. 修改 grammar_topics 表，新增 class_id 欄位（課程所屬班級）
ALTER TABLE grammar_topics ADD COLUMN IF NOT EXISTS class_id UUID REFERENCES classes(id) ON DELETE CASCADE;

-- =====================================================
-- RLS Policies（Row Level Security）
-- =====================================================

-- 啟用 classes 表的 RLS
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;

-- 老師可以查看所有班級（共同管理）
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'classes' AND policyname = 'teachers can view all classes') THEN
        EXECUTE 'CREATE POLICY "teachers can view all classes" ON classes FOR SELECT USING (
            EXISTS (
                SELECT 1 FROM users
                WHERE id = auth.uid() AND role = ''teacher''
            )
        )';
    END IF;
END $$;

-- 學生可以查看自己加入的班級
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'classes' AND policyname = 'students can view joined class') THEN
        EXECUTE 'CREATE POLICY "students can view joined class" ON classes FOR SELECT USING (
            id IN (SELECT class_id FROM users WHERE id = auth.uid())
        )';
    END IF;
END $$;

-- 老師可以建立班級
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'classes' AND policyname = 'teachers can create classes') THEN
        EXECUTE 'CREATE POLICY "teachers can create classes" ON classes FOR INSERT WITH CHECK (
            teacher_id = auth.uid()
            AND EXISTS (
                SELECT 1 FROM users
                WHERE id = auth.uid() AND role = ''teacher''
            )
        )';
    END IF;
END $$;

-- 老師可以更新所有班級（共同管理）
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'classes' AND policyname = 'teachers can update all classes') THEN
        EXECUTE 'CREATE POLICY "teachers can update all classes" ON classes FOR UPDATE USING (
            EXISTS (
                SELECT 1 FROM users
                WHERE id = auth.uid() AND role = ''teacher''
            )
        )';
    END IF;
END $$;

-- 老師可以刪除所有班級（共同管理）
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'classes' AND policyname = 'teachers can delete all classes') THEN
        EXECUTE 'CREATE POLICY "teachers can delete all classes" ON classes FOR DELETE USING (
            EXISTS (
                SELECT 1 FROM users
                WHERE id = auth.uid() AND role = ''teacher''
            )
        )';
    END IF;
END $$;

-- 所有已認證用戶可以透過班級代碼查詢班級（用於加入班級）
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'classes' AND policyname = 'authenticated users can find class by code') THEN
        EXECUTE 'CREATE POLICY "authenticated users can find class by code" ON classes FOR SELECT USING (auth.uid() IS NOT NULL)';
    END IF;
END $$;

-- =====================================================
-- 更新 users 表的 RLS Policy（允許更新 class_id）
-- =====================================================

-- 學生可以更新自己的 class_id
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'students can update own class_id') THEN
        EXECUTE 'CREATE POLICY "students can update own class_id" ON users FOR UPDATE USING (id = auth.uid()) WITH CHECK (id = auth.uid())';
    END IF;
END $$;

-- =====================================================
-- 更新 grammar_topics 表的 RLS Policy
-- =====================================================

-- 學生可以查看自己班級的課程
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'grammar_topics' AND policyname = 'students can view class topics') THEN
        EXECUTE 'CREATE POLICY "students can view class topics" ON grammar_topics FOR SELECT USING (
            class_id IN (SELECT class_id FROM users WHERE id = auth.uid())
        )';
    END IF;
END $$;

-- =====================================================
-- 自動生成不重複的 6 位數班級代碼函數
-- =====================================================

CREATE OR REPLACE FUNCTION generate_unique_class_code()
RETURNS TEXT AS $$
DECLARE
    new_code TEXT;
    code_exists BOOLEAN;
BEGIN
    LOOP
        -- 生成 6 位數字代碼（100000-999999）
        new_code := LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0');
        
        -- 檢查是否已存在
        SELECT EXISTS(SELECT 1 FROM classes WHERE code = new_code) INTO code_exists;
        
        -- 如果不存在則返回
        IF NOT code_exists THEN
            RETURN new_code;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 重新載入 Schema（讓 PostgREST 感知新欄位）
-- =====================================================

NOTIFY pgrst, 'reload schema';
