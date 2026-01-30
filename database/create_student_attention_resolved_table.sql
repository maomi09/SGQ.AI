-- 學生關注狀態解決記錄表
-- 用於記錄老師手動標記為「已完成」（解除關注狀態）的學生
CREATE TABLE IF NOT EXISTS student_attention_resolved (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  marked_by UUID REFERENCES users(id) ON DELETE SET NULL,
  marked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(student_id)
);

-- 建立索引以優化查詢
CREATE INDEX IF NOT EXISTS idx_student_attention_resolved_student_id ON student_attention_resolved(student_id);
CREATE INDEX IF NOT EXISTS idx_student_attention_resolved_marked_by ON student_attention_resolved(marked_by);
CREATE INDEX IF NOT EXISTS idx_student_attention_resolved_marked_at ON student_attention_resolved(marked_at);

-- 啟用 Row Level Security (RLS)
ALTER TABLE student_attention_resolved ENABLE ROW LEVEL SECURITY;

-- RLS 政策：教師可以讀取所有記錄
CREATE POLICY "Teachers can read all resolved records"
ON student_attention_resolved
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role = 'teacher'
  )
);

-- RLS 政策：教師可以插入記錄（標記為已完成）
CREATE POLICY "Teachers can insert resolved records"
ON student_attention_resolved
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role = 'teacher'
  )
);

-- RLS 政策：教師可以更新記錄
CREATE POLICY "Teachers can update resolved records"
ON student_attention_resolved
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role = 'teacher'
  )
);

-- RLS 政策：教師可以刪除記錄（取消標記）
CREATE POLICY "Teachers can delete resolved records"
ON student_attention_resolved
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role = 'teacher'
  )
);

