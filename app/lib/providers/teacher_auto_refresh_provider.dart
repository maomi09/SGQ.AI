import 'dart:async';
import 'package:flutter/foundation.dart';

/// 老師端共用的自動刷新倒數計時與刷新觸發。
/// 目的：讓 Dashboard 與 Statistics 的倒數顯示完全同步。
class TeacherAutoRefreshProvider extends ChangeNotifier {
  static const int refreshIntervalSeconds = 30;

  Timer? _timer;

  int _remainingSeconds = refreshIntervalSeconds;
  int _refreshToken = 0; // 每次觸發刷新就 +1，讓各頁籤可感知

  int get remainingSeconds => _remainingSeconds;
  int get refreshToken => _refreshToken;

  TeacherAutoRefreshProvider() {
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      var shouldNotify = false;

      if (_remainingSeconds > 0) {
        _remainingSeconds -= 1;
        shouldNotify = true;
      }

      if (_remainingSeconds <= 0) {
        _refreshToken += 1;
        _remainingSeconds = refreshIntervalSeconds;
        shouldNotify = true;
      }

      if (shouldNotify) notifyListeners();
    });
  }

  /// 手動立即刷新：立刻觸發刷新事件，並重置倒數。
  void forceRefreshNow() {
    _refreshToken += 1;
    _remainingSeconds = refreshIntervalSeconds;
    notifyListeners();
  }

  /// 只重置倒數（不觸發刷新事件）。
  void resetCountdownOnly() {
    _remainingSeconds = refreshIntervalSeconds;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

