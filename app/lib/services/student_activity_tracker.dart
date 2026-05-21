import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

/// 學生端分課程使用統計埋點（寫入 Supabase RPC，失敗時靜默略過）。
class StudentActivityTracker {
  StudentActivityTracker._();

  static final StudentActivityTracker instance = StudentActivityTracker._();

  static const String activeStatsTopicKey = 'student_active_stats_topic_id';
  static const String _loginTrackedKeysKey = 'usage_login_tracked_keys';

  final SupabaseService _supabaseService = SupabaseService();

  Future<void> setActiveTopicId(String? topicId) async {
    final prefs = await SharedPreferences.getInstance();
    if (topicId == null || topicId.isEmpty) {
      await prefs.remove(activeStatsTopicKey);
      return;
    }
    await prefs.setString(activeStatsTopicKey, topicId);
  }

  Future<String?> getActiveTopicId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(activeStatsTopicKey);
  }

  /// 同一 session 對同一課程只計一次登入。
  Future<void> trackTopicLoginIfNeeded(String grammarTopicId) async {
    if (grammarTopicId.isEmpty) return;
    await setActiveTopicId(grammarTopicId);

    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('study_active_session_id');
    if (sessionId == null || sessionId.isEmpty) return;

    final trackKey = '$sessionId:$grammarTopicId';
    final tracked = prefs.getStringList(_loginTrackedKeysKey) ?? [];
    if (tracked.contains(trackKey)) return;

    await _increment(grammarTopicId: grammarTopicId, loginDelta: 1);

    tracked.add(trackKey);
    if (tracked.length > 200) {
      tracked.removeRange(0, tracked.length - 200);
    }
    await prefs.setStringList(_loginTrackedKeysKey, tracked);
  }

  Future<void> trackSessionMinutes(String grammarTopicId, int minutes) async {
    if (grammarTopicId.isEmpty || minutes <= 0) return;
    await _increment(
      grammarTopicId: grammarTopicId,
      sessionMinutesDelta: minutes,
    );
  }

  Future<void> trackSessionMinutesForActiveTopic(int minutes) async {
    final topicId = await getActiveTopicId();
    if (topicId == null) return;
    await trackSessionMinutes(topicId, minutes);
  }

  Future<void> trackGrammarKeyPointView(String grammarTopicId) async {
    if (grammarTopicId.isEmpty) return;
    await _increment(
      grammarTopicId: grammarTopicId,
      grammarKeyPointViewDelta: 1,
    );
  }

  Future<void> trackReminderView(String grammarTopicId) async {
    if (grammarTopicId.isEmpty) return;
    await _increment(
      grammarTopicId: grammarTopicId,
      reminderViewDelta: 1,
    );
  }

  Future<void> trackQuestionEdit(String grammarTopicId) async {
    if (grammarTopicId.isEmpty) return;
    await _increment(
      grammarTopicId: grammarTopicId,
      questionEditDelta: 1,
    );
  }

  Future<void> trackQuestionStageCompleted({
    required String grammarTopicId,
    required int completionSeconds,
  }) async {
    if (grammarTopicId.isEmpty) return;
    await _increment(
      grammarTopicId: grammarTopicId,
      questionCompletionDelta: 1,
      completionSecondsDelta: completionSeconds.clamp(0, 86400),
    );
  }

  Future<void> _increment({
    required String grammarTopicId,
    int loginDelta = 0,
    int sessionMinutesDelta = 0,
    int questionCompletionDelta = 0,
    int completionSecondsDelta = 0,
    int questionEditDelta = 0,
    int grammarKeyPointViewDelta = 0,
    int reminderViewDelta = 0,
  }) async {
    try {
      await _supabaseService.incrementStudentTopicUsage(
        grammarTopicId: grammarTopicId,
        loginDelta: loginDelta,
        sessionMinutesDelta: sessionMinutesDelta,
        questionCompletionDelta: questionCompletionDelta,
        completionSecondsDelta: completionSecondsDelta,
        questionEditDelta: questionEditDelta,
        grammarKeyPointViewDelta: grammarKeyPointViewDelta,
        reminderViewDelta: reminderViewDelta,
      );
    } catch (_) {
      // 統計失敗不應中斷學習流程
    }
  }
}
