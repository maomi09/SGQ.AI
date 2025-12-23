-- 對話消息表
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id UUID REFERENCES questions(id) ON DELETE CASCADE,
  grammar_topic_id UUID REFERENCES grammar_topics(id) ON DELETE CASCADE,
  student_id UUID REFERENCES users(id) ON DELETE CASCADE,
  stage INTEGER NOT NULL CHECK (stage >= 1 AND stage <= 4),
  message_type TEXT NOT NULL CHECK (message_type IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 建立索引以優化查詢
CREATE INDEX IF NOT EXISTS idx_chat_messages_question_id ON chat_messages(question_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_student_id ON chat_messages(student_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_grammar_topic_id ON chat_messages(grammar_topic_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_stage ON chat_messages(stage);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at);

-- 啟用 Row Level Security (RLS)
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- RLS 政策：學生只能管理自己的對話消息
CREATE POLICY "Students can manage own chat messages"
ON chat_messages
FOR ALL
USING (
  auth.uid() = student_id
);

-- RLS 政策：教師可以讀取所有學生的對話消息
CREATE POLICY "Teachers can read all student chat messages"
ON chat_messages
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role = 'teacher'
  )
);

