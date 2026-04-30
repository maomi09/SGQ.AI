CREATE TABLE IF NOT EXISTS teacher_student_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sender_role TEXT NOT NULL CHECK (sender_role IN ('teacher', 'student')),
  content TEXT NOT NULL,
  is_hand_raise BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP INDEX IF EXISTS idx_teacher_student_messages_class_student_created;
ALTER TABLE teacher_student_messages
DROP COLUMN IF EXISTS class_id;

CREATE INDEX IF NOT EXISTS idx_teacher_student_messages_student_created
  ON teacher_student_messages (student_id, created_at);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'teacher_student_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.teacher_student_messages;
  END IF;
END $$;

ALTER TABLE teacher_student_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS teacher_student_messages_select ON teacher_student_messages;
CREATE POLICY teacher_student_messages_select
ON teacher_student_messages
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM users u
    WHERE u.id::text = auth.uid()::text
      AND (
        (u.role = 'teacher')
        OR (
          u.role = 'student'
          AND u.id::text = teacher_student_messages.student_id::text
        )
      )
  )
);

DROP POLICY IF EXISTS teacher_student_messages_insert ON teacher_student_messages;
CREATE POLICY teacher_student_messages_insert
ON teacher_student_messages
FOR INSERT
TO authenticated
WITH CHECK (
  (
    sender_role = 'student'
    AND auth.uid()::text = sender_id::text
    AND auth.uid()::text = student_id::text
  )
  OR (
    sender_role = 'teacher'
    AND auth.uid()::text = sender_id::text
    AND EXISTS (
      SELECT 1
      FROM users u
      WHERE u.id::text = auth.uid()::text
        AND u.role = 'teacher'
    )
  )
);

NOTIFY pgrst, 'reload schema';
