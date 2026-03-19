-- =====================================================
-- SGQ.AI 班級系統資料遷移腳本
-- 將現有資料遷移到預設班級
-- 請在執行 supabase_class_system.sql 之後執行此腳本
-- =====================================================

-- 1. 建立全域第一個班級「A班」（若不存在）
DO $$
DECLARE
    first_teacher_id UUID;
    class_a_id UUID;
    new_class_code TEXT;
BEGIN
    -- 先找任一位老師作為 A班建立者（僅紀錄用途）
    SELECT id INTO first_teacher_id
    FROM users
    WHERE role = 'teacher'
    ORDER BY created_at ASC
    LIMIT 1;

    IF first_teacher_id IS NULL THEN
        RAISE EXCEPTION '找不到老師帳號，無法建立 A班';
    END IF;

    -- 優先找名稱為 A班 的班級
    SELECT id INTO class_a_id
    FROM classes
    WHERE name = 'A班'
    ORDER BY created_at ASC
    LIMIT 1;

    -- 若不存在，建立 A班
    IF class_a_id IS NULL THEN
        LOOP
            new_class_code := LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0');
            EXIT WHEN NOT EXISTS (SELECT 1 FROM classes WHERE code = new_class_code);
        END LOOP;

        INSERT INTO classes (name, code, teacher_id, created_at, updated_at)
        VALUES ('A班', new_class_code, first_teacher_id, NOW(), NOW())
        RETURNING id INTO class_a_id;

        RAISE NOTICE 'Created class A班 with code: %', new_class_code;
    ELSE
        RAISE NOTICE 'A班 already exists, class_id: %', class_a_id;
    END IF;
END $$;

-- 2. 將現有課程（沒有班級者）移轉到 A班
DO $$
DECLARE
    class_a_id UUID;
    topic_count INT;
BEGIN
    SELECT id INTO class_a_id
    FROM classes
    WHERE name = 'A班'
    ORDER BY created_at ASC
    LIMIT 1;

    IF class_a_id IS NULL THEN
        RAISE EXCEPTION '找不到 A班，無法遷移課程';
    END IF;

    SELECT COUNT(*) INTO topic_count
    FROM grammar_topics
    WHERE class_id IS NULL;

    UPDATE grammar_topics
    SET class_id = class_a_id
    WHERE class_id IS NULL;

    RAISE NOTICE 'Migrated % grammar topics to A班 (%).', topic_count, class_a_id;
END $$;

-- 3. 將現有學生（沒有班級者）移轉到 A班

DO $$
DECLARE
    class_a_id UUID;
    student_count INT;
BEGIN
    SELECT id INTO class_a_id
    FROM classes
    WHERE name = 'A班'
    ORDER BY created_at ASC
    LIMIT 1;

    IF class_a_id IS NULL THEN
        RAISE EXCEPTION '找不到 A班，無法遷移學生';
    END IF;

    SELECT COUNT(*) INTO student_count 
    FROM users 
    WHERE role = 'student' AND class_id IS NULL;

    UPDATE users
    SET class_id = class_a_id
    WHERE role = 'student'
      AND class_id IS NULL;

    RAISE NOTICE 'Migrated % students to A班 (%).', student_count, class_a_id;
END $$;

-- 4. 驗證文法重點與提醒是否已隨課程完成遷移
-- 說明：grammar_key_points / reminders 是以 grammar_topic_id 關聯課程，
--       課程搬到 A班後，資料會自然跟著課程，不需額外更新 class_id。
DO $$
DECLARE
    class_a_id UUID;
    key_points_in_a_class INT;
    reminders_in_a_class INT;
    orphan_key_points INT;
    orphan_reminders INT;
BEGIN
    SELECT id INTO class_a_id
    FROM classes
    WHERE name = 'A班'
    ORDER BY created_at ASC
    LIMIT 1;

    IF class_a_id IS NULL THEN
        RAISE EXCEPTION '找不到 A班，無法驗證文法重點與提醒遷移結果';
    END IF;

    SELECT COUNT(*) INTO key_points_in_a_class
    FROM grammar_key_points gkp
    JOIN grammar_topics gt ON gt.id = gkp.grammar_topic_id
    WHERE gt.class_id = class_a_id;

    SELECT COUNT(*) INTO reminders_in_a_class
    FROM reminders r
    JOIN grammar_topics gt ON gt.id = r.grammar_topic_id
    WHERE gt.class_id = class_a_id;

    SELECT COUNT(*) INTO orphan_key_points
    FROM grammar_key_points gkp
    LEFT JOIN grammar_topics gt ON gt.id = gkp.grammar_topic_id
    WHERE gt.id IS NULL;

    SELECT COUNT(*) INTO orphan_reminders
    FROM reminders r
    LEFT JOIN grammar_topics gt ON gt.id = r.grammar_topic_id
    WHERE gt.id IS NULL;

    RAISE NOTICE 'Grammar key points linked to A班 topics: %', key_points_in_a_class;
    RAISE NOTICE 'Reminders linked to A班 topics: %', reminders_in_a_class;
    RAISE NOTICE 'Orphan grammar key points: %', orphan_key_points;
    RAISE NOTICE 'Orphan reminders: %', orphan_reminders;

    IF orphan_key_points > 0 OR orphan_reminders > 0 THEN
        RAISE WARNING 'Found orphan key points/reminders. Please check data integrity manually.';
    END IF;
END $$;

-- 5. 驗證遷移結果
DO $$
DECLARE
    class_count INT;
    topic_without_class INT;
    student_without_class INT;
    class_a_count INT;
BEGIN
    SELECT COUNT(*) INTO class_count FROM classes;
    SELECT COUNT(*) INTO class_a_count FROM classes WHERE name = 'A班';
    SELECT COUNT(*) INTO topic_without_class FROM grammar_topics WHERE class_id IS NULL;
    SELECT COUNT(*) INTO student_without_class FROM users WHERE role = 'student' AND class_id IS NULL;
    
    RAISE NOTICE '=== Migration Summary ===';
    RAISE NOTICE 'Total classes: %', class_count;
    RAISE NOTICE 'A班 count: %', class_a_count;
    RAISE NOTICE 'Topics without class: %', topic_without_class;
    RAISE NOTICE 'Students without class: %', student_without_class;
    
    IF topic_without_class > 0 OR student_without_class > 0 THEN
        RAISE WARNING 'Some data may not have been migrated. Please check manually.';
    ELSE
        RAISE NOTICE 'Migration completed successfully!';
    END IF;
END $$;

-- 6. 重新載入 Schema
NOTIFY pgrst, 'reload schema';
