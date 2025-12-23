-- 在 questions 表中添加教師評語字段
-- 執行此腳本來添加評語功能

ALTER TABLE questions 
ADD COLUMN IF NOT EXISTS teacher_comment TEXT,
ADD COLUMN IF NOT EXISTS teacher_comment_updated_at TIMESTAMP WITH TIME ZONE;

-- 添加索引以優化查詢
CREATE INDEX IF NOT EXISTS idx_questions_teacher_comment ON questions(teacher_comment) WHERE teacher_comment IS NOT NULL;

