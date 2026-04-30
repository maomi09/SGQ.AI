-- student_attention_resolved 的 RLS 修正
-- 目的：
-- 1) 允許學生手動確認完成（只能操作自己的資料）
-- 2) 允許老師查詢與管理全班完成狀態

ALTER TABLE student_attention_resolved ENABLE ROW LEVEL SECURITY;

-- 學生可讀自己的完成標記
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'student_attention_resolved'
          AND policyname = 'students can read own completion mark'
    ) THEN
        EXECUTE '
            CREATE POLICY "students can read own completion mark"
            ON student_attention_resolved
            FOR SELECT
            USING (student_id = auth.uid())
        ';
    END IF;
END $$;

-- 學生可更新自己的完成標記
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'student_attention_resolved'
          AND policyname = 'students can update own completion mark'
    ) THEN
        EXECUTE '
            CREATE POLICY "students can update own completion mark"
            ON student_attention_resolved
            FOR UPDATE
            USING (student_id = auth.uid())
            WITH CHECK (student_id = auth.uid() AND marked_by = auth.uid())
        ';
    END IF;
END $$;

-- 學生可新增/更新自己的完成標記
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'student_attention_resolved'
          AND policyname = 'students can upsert own completion mark'
    ) THEN
        EXECUTE '
            CREATE POLICY "students can upsert own completion mark"
            ON student_attention_resolved
            FOR INSERT
            WITH CHECK (student_id = auth.uid() AND marked_by = auth.uid())
        ';
    END IF;
END $$;

-- 學生可刪除自己的完成標記
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'student_attention_resolved'
          AND policyname = 'students can delete own completion mark'
    ) THEN
        EXECUTE '
            CREATE POLICY "students can delete own completion mark"
            ON student_attention_resolved
            FOR DELETE
            USING (student_id = auth.uid())
        ';
    END IF;
END $$;

-- 老師可讀全部完成標記
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'student_attention_resolved'
          AND policyname = 'teachers can read all completion marks'
    ) THEN
        EXECUTE '
            CREATE POLICY "teachers can read all completion marks"
            ON student_attention_resolved
            FOR SELECT
            USING (
                EXISTS (
                    SELECT 1
                    FROM users
                    WHERE id = auth.uid()
                      AND role = ''teacher''
                )
            )
        ';
    END IF;
END $$;

-- 老師可新增/更新全部完成標記
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'student_attention_resolved'
          AND policyname = 'teachers can upsert all completion marks'
    ) THEN
        EXECUTE '
            CREATE POLICY "teachers can upsert all completion marks"
            ON student_attention_resolved
            FOR INSERT
            WITH CHECK (
                EXISTS (
                    SELECT 1
                    FROM users
                    WHERE id = auth.uid()
                      AND role = ''teacher''
                )
            )
        ';
    END IF;
END $$;

-- 老師可刪除全部完成標記
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'student_attention_resolved'
          AND policyname = 'teachers can delete all completion marks'
    ) THEN
        EXECUTE '
            CREATE POLICY "teachers can delete all completion marks"
            ON student_attention_resolved
            FOR DELETE
            USING (
                EXISTS (
                    SELECT 1
                    FROM users
                    WHERE id = auth.uid()
                      AND role = ''teacher''
                )
            )
        ';
    END IF;
END $$;

-- 老師可更新全部完成標記
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'student_attention_resolved'
          AND policyname = 'teachers can update all completion marks'
    ) THEN
        EXECUTE '
            CREATE POLICY "teachers can update all completion marks"
            ON student_attention_resolved
            FOR UPDATE
            USING (
                EXISTS (
                    SELECT 1
                    FROM users
                    WHERE id = auth.uid()
                      AND role = ''teacher''
                )
            )
            WITH CHECK (
                EXISTS (
                    SELECT 1
                    FROM users
                    WHERE id = auth.uid()
                      AND role = ''teacher''
                )
            )
        ';
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';
