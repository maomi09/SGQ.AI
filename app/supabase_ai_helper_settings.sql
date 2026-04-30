-- 班級層級 AI 小幫手開關
-- 目的：
-- 1) 老師可依班級設定是否允許學生使用 AI 小幫手
-- 2) 學生端依自己班級設定決定是否顯示 AI 小幫手入口

ALTER TABLE classes
ADD COLUMN IF NOT EXISTS ai_helper_enabled BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON COLUMN classes.ai_helper_enabled IS '是否允許此班級學生使用 AI 小幫手';
