-- 學生分課程使用統計（階段 B）
-- 六項指標：階段完成次數與耗時、修改題目次數、登入次數、單次使用時長（分鐘累計）、文法重點瀏覽、出題重點瀏覽
-- 請在 Supabase SQL Editor 執行此腳本

CREATE TABLE IF NOT EXISTS student_topic_usage_stats (
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  grammar_topic_id UUID NOT NULL REFERENCES grammar_topics(id) ON DELETE CASCADE,
  question_completion_count INT NOT NULL DEFAULT 0,
  total_question_completion_seconds BIGINT NOT NULL DEFAULT 0,
  question_edit_count INT NOT NULL DEFAULT 0,
  login_count INT NOT NULL DEFAULT 0,
  total_session_minutes INT NOT NULL DEFAULT 0,
  grammar_key_point_view_count INT NOT NULL DEFAULT 0,
  reminder_view_count INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (student_id, grammar_topic_id)
);

CREATE INDEX IF NOT EXISTS idx_student_topic_usage_stats_topic
  ON student_topic_usage_stats (grammar_topic_id);

ALTER TABLE student_topic_usage_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Students manage own topic usage stats" ON student_topic_usage_stats;
CREATE POLICY "Students manage own topic usage stats"
  ON student_topic_usage_stats
  FOR ALL
  USING (student_id = auth.uid())
  WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS "Teachers read topic usage stats" ON student_topic_usage_stats;
CREATE POLICY "Teachers read topic usage stats"
  ON student_topic_usage_stats
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'teacher'
    )
  );

CREATE OR REPLACE FUNCTION public.increment_student_topic_usage(
  p_grammar_topic_id UUID,
  p_login_delta INT DEFAULT 0,
  p_session_minutes_delta INT DEFAULT 0,
  p_question_completion_delta INT DEFAULT 0,
  p_completion_seconds_delta BIGINT DEFAULT 0,
  p_question_edit_delta INT DEFAULT 0,
  p_grammar_key_point_view_delta INT DEFAULT 0,
  p_reminder_view_delta INT DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := auth.uid();
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_grammar_topic_id IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO student_topic_usage_stats (
    student_id,
    grammar_topic_id,
    login_count,
    total_session_minutes,
    question_completion_count,
    total_question_completion_seconds,
    question_edit_count,
    grammar_key_point_view_count,
    reminder_view_count,
    updated_at
  )
  VALUES (
    v_student_id,
    p_grammar_topic_id,
    GREATEST(0, p_login_delta),
    GREATEST(0, p_session_minutes_delta),
    GREATEST(0, p_question_completion_delta),
    GREATEST(0, p_completion_seconds_delta),
    GREATEST(0, p_question_edit_delta),
    GREATEST(0, p_grammar_key_point_view_delta),
    GREATEST(0, p_reminder_view_delta),
    NOW()
  )
  ON CONFLICT (student_id, grammar_topic_id) DO UPDATE SET
    login_count = student_topic_usage_stats.login_count + GREATEST(0, p_login_delta),
    total_session_minutes = student_topic_usage_stats.total_session_minutes + GREATEST(0, p_session_minutes_delta),
    question_completion_count = student_topic_usage_stats.question_completion_count + GREATEST(0, p_question_completion_delta),
    total_question_completion_seconds = student_topic_usage_stats.total_question_completion_seconds + GREATEST(0, p_completion_seconds_delta),
    question_edit_count = student_topic_usage_stats.question_edit_count + GREATEST(0, p_question_edit_delta),
    grammar_key_point_view_count = student_topic_usage_stats.grammar_key_point_view_count + GREATEST(0, p_grammar_key_point_view_delta),
    reminder_view_count = student_topic_usage_stats.reminder_view_count + GREATEST(0, p_reminder_view_delta),
    updated_at = NOW();
END;
$$;

REVOKE ALL ON FUNCTION public.increment_student_topic_usage(UUID, INT, INT, INT, BIGINT, INT, INT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_student_topic_usage(UUID, INT, INT, INT, BIGINT, INT, INT, INT) TO authenticated;

NOTIFY pgrst, 'reload schema';
