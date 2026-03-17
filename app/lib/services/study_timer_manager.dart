import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

/// 統一管理學生學習時數的本地心跳與結算（單例）。
///
/// 設計目標：
/// - 以 `Timer.periodic` 每 10 秒寫入 `last_heartbeat`（本地 SharedPreferences）
/// - 以 `study_start_time` / `last_heartbeat` 做「有效時數」補償與結算
/// - 在 App 進入背景 / 登出時，立即結算並同步到後端（更新 user_sessions.end_time）
/// - 防呆：單次時數超過 4 小時則視為異常，設為 0（不更新 end_time）
class StudyTimerManager {
  StudyTimerManager._();

  static final StudyTimerManager instance = StudyTimerManager._();

  static const String _kStudyStartTimeMs = 'study_start_time_ms';
  static const String _kLastHeartbeatMs = 'last_heartbeat_ms';
  static const String _kActiveStudentId = 'study_active_student_id';
  static const String _kActiveSessionId = 'study_active_session_id';

  static const Duration heartbeatInterval = Duration(seconds: 10);
  static const Duration maxSingleStudy = Duration(hours: 4);

  final SupabaseService _supabaseService = SupabaseService();

  Timer? _timer;
  bool get isRunning => _timer != null;
  DateTime? _lastHeartbeatUpdateErrorLogAt;

  /// 登入/回到前景後呼叫：
  /// - 先做一次補償結算（避免上次閃退/強制關閉造成 end_time 遺漏）
  /// - 再開始新的心跳計時
  Future<void> start({
    required String studentId,
    required String sessionId,
  }) async {
    await recoverAndSyncIfNeeded(studentId: studentId);

    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await prefs.setString(_kActiveStudentId, studentId);
    await prefs.setString(_kActiveSessionId, sessionId);
    await prefs.setInt(_kStudyStartTimeMs, nowMs);
    await prefs.setInt(_kLastHeartbeatMs, nowMs);

    _timer?.cancel();
    _timer = Timer.periodic(heartbeatInterval, (_) async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 1) 本地心跳（用於補償結算）
      try {
        final p = await SharedPreferences.getInstance();
        await p.setInt(_kLastHeartbeatMs, nowMs);
      } catch (e) {
        // 本地寫入失敗不應中斷學習流程
        final now = DateTime.now();
        if (_lastHeartbeatUpdateErrorLogAt == null ||
            now.difference(_lastHeartbeatUpdateErrorLogAt!) > const Duration(minutes: 1)) {
          _lastHeartbeatUpdateErrorLogAt = now;
          print('StudyTimerManager: failed to write local heartbeat: $e');
        }
      }

      // 2) 後端心跳（用於老師端「上線中」判斷）
      try {
        final ok = await _supabaseService.updateSessionHeartbeat(
          sessionId: sessionId,
          heartbeatTime: DateTime.fromMillisecondsSinceEpoch(nowMs),
        );
        if (!ok) {
          final now = DateTime.now();
          if (_lastHeartbeatUpdateErrorLogAt == null ||
              now.difference(_lastHeartbeatUpdateErrorLogAt!) > const Duration(minutes: 1)) {
            _lastHeartbeatUpdateErrorLogAt = now;
            print('StudyTimerManager: backend heartbeat update failed (see Supabase error above).');
          }
        }
      } catch (e) {
        final now = DateTime.now();
        if (_lastHeartbeatUpdateErrorLogAt == null ||
            now.difference(_lastHeartbeatUpdateErrorLogAt!) > const Duration(minutes: 1)) {
          _lastHeartbeatUpdateErrorLogAt = now;
          print('StudyTimerManager: backend heartbeat exception: $e');
        }
      }
    });
  }

  /// App 進入背景 / 登出時呼叫：
  /// - 停止心跳
  /// - 立即結算（last_heartbeat - study_start_time）
  /// - 若合理則同步到後端（把 user_sessions.end_time 設為 last_heartbeat）
  Future<void> stop({bool clearLocalCache = false}) async {
    _timer?.cancel();
    _timer = null;

    try {
      await syncToBackend();
    } finally {
      if (clearLocalCache) {
        await clearLocal();
      }
    }
  }

  /// 依本地快取把本次 session 結算並同步到後端。
  ///
  /// 注意：此方法只會「結束」目前 local cache 指向的 session；
  /// 若 local cache 不完整，會安全地跳過。
  Future<void> syncToBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString(_kActiveStudentId);
    final sessionId = prefs.getString(_kActiveSessionId);
    final startMs = prefs.getInt(_kStudyStartTimeMs);
    final lastMs = prefs.getInt(_kLastHeartbeatMs);

    if (studentId == null || studentId.isEmpty) return;
    if (sessionId == null || sessionId.isEmpty) return;
    if (startMs == null || lastMs == null) return;

    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);

    if (!last.isAfter(start)) return;

    final duration = last.difference(start);
    if (duration > maxSingleStudy) {
      // 異常（可能掛機、時間錯亂），不更新 end_time，避免污染統計
      return;
    }

    try {
      await _supabaseService.endSession(sessionId, endTime: last);
    } catch (_) {
      // 後端同步失敗：保留本地快取，讓下次登入/啟動再補償
      rethrow;
    }
  }

  /// 異常中斷補償：
  /// 若偵測到本地有「上次未結算」的 start/heartbeat/sessionId，
  /// 會用 last_heartbeat - study_start_time 結算並嘗試同步到後端。
  Future<void> recoverAndSyncIfNeeded({required String studentId}) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedStudentId = prefs.getString(_kActiveStudentId);

    // 只補償同一個學生，避免跨帳號誤結算
    if (cachedStudentId == null || cachedStudentId != studentId) {
      return;
    }

    final sessionId = prefs.getString(_kActiveSessionId);
    final startMs = prefs.getInt(_kStudyStartTimeMs);
    final lastMs = prefs.getInt(_kLastHeartbeatMs);
    if (sessionId == null || startMs == null || lastMs == null) return;

    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    if (!last.isAfter(start)) return;

    final duration = last.difference(start);
    if (duration > maxSingleStudy) {
      // 異常：直接清掉，避免永遠卡住
      await clearLocal();
      return;
    }

    try {
      await _supabaseService.endSession(sessionId, endTime: last);
      await clearLocal();
    } catch (_) {
      // 補償同步失敗：保留快取，下次再嘗試
    }
  }

  Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStudyStartTimeMs);
    await prefs.remove(_kLastHeartbeatMs);
    await prefs.remove(_kActiveStudentId);
    await prefs.remove(_kActiveSessionId);
  }
}

