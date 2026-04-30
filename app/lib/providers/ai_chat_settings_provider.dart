import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../services/supabase_service.dart';

class AiChatSettingsProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  bool _isEnabled = false;
  bool _isLoaded = false;
  bool _isUpdating = false;
  String? _boundClassId;
  RealtimeChannel? _classSettingsChannel;
  String? _realtimeClassId;
  Timer? _pollingTimer;

  bool get isEnabled => _isEnabled;
  bool get isLoaded => _isLoaded;
  bool get isUpdating => _isUpdating;
  String? get boundClassId => _boundClassId;

  AiChatSettingsProvider();

  Future<void> refreshForStudent({
    required String studentId,
    String? classId,
  }) async {
    try {
      _boundClassId = classId;
      _isEnabled = await _supabaseService.getStudentAiHelperEnabled(studentId);
    } catch (_) {
      _isEnabled = true;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }

    await bindStudentRealtime(
      studentId: studentId,
      classId: classId,
    );
  }

  Future<void> refreshForClass(String classId) async {
    try {
      _boundClassId = classId;
      _isEnabled = await _supabaseService.getClassAiHelperEnabled(classId);
    } catch (_) {
      _isEnabled = true;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<bool> setEnabledForClass({
    required String classId,
    required bool enabled,
  }) async {
    _isUpdating = true;
    notifyListeners();
    try {
      final success = await _supabaseService.updateClassAiHelperEnabled(
        classId,
        enabled,
      );
      if (success) {
        _boundClassId = classId;
        _isEnabled = enabled;
      }
      return success;
    } catch (_) {
      return false;
    } finally {
      _isLoaded = true;
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<void> bindStudentRealtime({
    required String studentId,
    String? classId,
  }) async {
    String? effectiveClassId = classId;
    if (effectiveClassId == null || effectiveClassId.isEmpty) {
      try {
        final enabled = await _supabaseService.getStudentAiHelperEnabled(studentId);
        _isEnabled = enabled;
        _isLoaded = true;
        notifyListeners();
      } catch (_) {}
      return;
    }

    if (_realtimeClassId == effectiveClassId && _classSettingsChannel != null) {
      return;
    }

    disposeRealtimeSubscription();
    _realtimeClassId = effectiveClassId;

    final channelName =
        'class_ai_helper_${effectiveClassId}_${DateTime.now().millisecondsSinceEpoch}';
    _classSettingsChannel = _supabaseClient
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'classes',
          callback: (payload) {
            final changedClassId = payload.newRecord['id']?.toString();
            if (changedClassId != effectiveClassId) {
              return;
            }
            final value = payload.newRecord['ai_helper_enabled'];
            if (value is bool && value != _isEnabled) {
              _isEnabled = value;
              _isLoaded = true;
              notifyListeners();
            }
          },
        )
        .subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            return;
          }
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            await Future.delayed(const Duration(milliseconds: 1200));
            if (_realtimeClassId == effectiveClassId) {
              await bindStudentRealtime(
                studentId: studentId,
                classId: effectiveClassId,
              );
            }
          }
        });

    _startPollingFallback(effectiveClassId);
  }

  void _startPollingFallback(String classId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_realtimeClassId != classId) return;
      try {
        final latest = await _supabaseService.getClassAiHelperEnabled(classId);
        if (latest != _isEnabled) {
          _isEnabled = latest;
          _isLoaded = true;
          notifyListeners();
        }
      } catch (_) {
        // 輪詢備援失敗不阻斷主流程
      }
    });
  }

  void disposeRealtimeSubscription() {
    _classSettingsChannel?.unsubscribe();
    _classSettingsChannel = null;
    _realtimeClassId = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    disposeRealtimeSubscription();
    super.dispose();
  }
}

