-- 手動確認完成改為「按課程分開」
-- 目標：
-- 1) 同一學生可在不同課程各自確認完成
-- 2) 同一課程可重複按下（更新時間）

ALTER TABLE student_attention_resolved
ADD COLUMN IF NOT EXISTS grammar_topic_id UUID REFERENCES grammar_topics(id) ON DELETE CASCADE;

-- 將舊資料補上課程（優先使用該學生最新題目所屬課程）
WITH latest_topic AS (
  SELECT DISTINCT ON (q.student_id)
    q.student_id,
    q.grammar_topic_id
  FROM questions q
  ORDER BY q.student_id, COALESCE(q.updated_at, q.created_at) DESC
)
UPDATE student_attention_resolved sar
SET grammar_topic_id = lt.grammar_topic_id
FROM latest_topic lt
WHERE sar.student_id = lt.student_id
  AND sar.grammar_topic_id IS NULL;

-- 若仍無法補齊課程（例如學生完全沒有題目），刪除舊的無課程記錄
DELETE FROM student_attention_resolved
WHERE grammar_topic_id IS NULL;

ALTER TABLE student_attention_resolved
ALTER COLUMN grammar_topic_id SET NOT NULL;

-- 移除舊唯一鍵（僅 student_id）
ALTER TABLE student_attention_resolved
DROP CONSTRAINT IF EXISTS student_attention_resolved_student_id_key;

-- 新唯一鍵：同一學生在同一課程只能有一筆
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'student_attention_resolved_student_topic_key'
  ) THEN
    ALTER TABLE student_attention_resolved
    ADD CONSTRAINT student_attention_resolved_student_topic_key
    UNIQUE (student_id, grammar_topic_id);
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
