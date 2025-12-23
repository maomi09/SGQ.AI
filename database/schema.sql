-- 使用者表
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('student', 'teacher')),
  student_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 文法主題表
CREATE TABLE IF NOT EXISTS grammar_topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  teacher_id UUID REFERENCES users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 文法重點表
CREATE TABLE IF NOT EXISTS grammar_key_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grammar_topic_id UUID REFERENCES grammar_topics(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  "order" INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 出題重點提醒表
CREATE TABLE IF NOT EXISTS reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grammar_topic_id UUID REFERENCES grammar_topics(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  "order" INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 題目表
CREATE TABLE IF NOT EXISTS questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES users(id) ON DELETE CASCADE,
  grammar_topic_id UUID REFERENCES grammar_topics(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('multipleChoice', 'shortAnswer')),
  question TEXT NOT NULL,
  options JSONB,
  correct_answer TEXT,
  explanation TEXT,
  stage INTEGER NOT NULL DEFAULT 1 CHECK (stage >= 1 AND stage <= 4),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 徽章表
CREATE TABLE IF NOT EXISTS badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES users(id) ON DELETE CASCADE,
  grammar_topic_id UUID REFERENCES grammar_topics(id) ON DELETE CASCADE,
  badge_type TEXT NOT NULL,
  badge_name TEXT NOT NULL,
  description TEXT NOT NULL,
  earned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 使用者會話表（用於統計）
CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES users(id) ON DELETE CASCADE,
  start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  end_time TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 建立索引
CREATE INDEX IF NOT EXISTS idx_questions_student_id ON questions(student_id);
CREATE INDEX IF NOT EXISTS idx_questions_grammar_topic_id ON questions(grammar_topic_id);
CREATE INDEX IF NOT EXISTS idx_badges_student_id ON badges(student_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_student_id ON user_sessions(student_id);
CREATE INDEX IF NOT EXISTS idx_grammar_key_points_topic_id ON grammar_key_points(grammar_topic_id);
CREATE INDEX IF NOT EXISTS idx_reminders_topic_id ON reminders(grammar_topic_id);

-- 啟用 Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE grammar_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE grammar_key_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- RLS 政策（範例，需要根據實際需求調整）
-- 使用者可以讀取自己的資料
CREATE POLICY "Users can read own data" ON users
  FOR SELECT USING (auth.uid() = id);

-- 使用者可以插入自己的資料（註冊時使用）
CREATE POLICY "Users can insert own data" ON users
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- 使用者可以更新自己的資料
CREATE POLICY "Users can update own data" ON users
  FOR UPDATE 
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 所有使用者可以讀取文法主題
CREATE POLICY "Anyone can read grammar topics" ON grammar_topics
  FOR SELECT USING (true);

-- 老師可以管理文法主題
CREATE POLICY "Teachers can manage grammar topics" ON grammar_topics
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'teacher'
    )
  );

-- 學生可以讀取文法重點和提醒
CREATE POLICY "Anyone can read grammar key points" ON grammar_key_points
  FOR SELECT USING (true);

CREATE POLICY "Anyone can read reminders" ON reminders
  FOR SELECT USING (true);

-- 老師可以管理文法重點和提醒
CREATE POLICY "Teachers can manage grammar key points" ON grammar_key_points
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'teacher'
    )
  );

CREATE POLICY "Teachers can manage reminders" ON reminders
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'teacher'
    )
  );

-- 學生可以管理自己的題目
CREATE POLICY "Students can manage own questions" ON questions
  FOR ALL USING (auth.uid() = student_id);

-- 學生可以讀取自己的徽章
CREATE POLICY "Students can read own badges" ON badges
  FOR SELECT USING (auth.uid() = student_id);

-- 學生可以管理自己的會話
CREATE POLICY "Students can manage own sessions" ON user_sessions
  FOR ALL USING (auth.uid() = student_id);

