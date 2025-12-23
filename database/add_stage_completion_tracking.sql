-- 添加階段完成追蹤欄位到 questions 表
-- 使用 JSONB 存儲每個階段的完成時間
ALTER TABLE questions 
ADD COLUMN IF NOT EXISTS completed_stages JSONB DEFAULT '{}'::jsonb;

-- 添加索引以優化查詢
CREATE INDEX IF NOT EXISTS idx_questions_completed_stages 
ON questions USING GIN (completed_stages);

-- 添加註釋說明
COMMENT ON COLUMN questions.completed_stages IS '存儲每個階段的完成時間，格式: {"1": "2024-01-01T00:00:00Z", "2": "2024-01-02T00:00:00Z"}';

