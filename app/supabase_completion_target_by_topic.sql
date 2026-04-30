-- 完成標準題數改為「課程層級」
-- 每個課程可設定不同完成標準

ALTER TABLE grammar_topics
ADD COLUMN IF NOT EXISTS completion_question_target INTEGER NOT NULL DEFAULT 5;

COMMENT ON COLUMN grammar_topics.completion_question_target IS '課程完成標準題數';

NOTIFY pgrst, 'reload schema';
