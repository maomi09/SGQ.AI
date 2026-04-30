-- 班級完成標準題數設定（第 2 期）
-- 老師可設定該班學生達成「完成」所需題數

ALTER TABLE classes
ADD COLUMN IF NOT EXISTS completion_question_target INTEGER NOT NULL DEFAULT 5;

COMMENT ON COLUMN classes.completion_question_target IS '班級完成標準題數（學生題目數達標視為完成）';
