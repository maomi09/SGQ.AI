-- ============================================
-- 啟用 Supabase Realtime 所需的表
-- ============================================
-- 執行此腳本來將表添加到 Realtime publication
-- 這樣 Flutter 應用才能通過 Realtime 訂閱這些表的變化

-- 將 grammar_topics 表添加到 Realtime publication
-- 允許訂閱新課程的 INSERT 事件
ALTER PUBLICATION supabase_realtime ADD TABLE grammar_topics;

-- 將 questions 表添加到 Realtime publication
-- 允許訂閱評語更新的 UPDATE 事件
ALTER PUBLICATION supabase_realtime ADD TABLE questions;

-- 將 badges 表添加到 Realtime publication
-- 允許訂閱新徽章的 INSERT 事件
ALTER PUBLICATION supabase_realtime ADD TABLE badges;

-- 驗證表已添加
SELECT 
  schemaname,
  tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename IN ('grammar_topics', 'questions', 'badges')
ORDER BY tablename;
