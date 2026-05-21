import 'package:flutter/foundation.dart';

/// 老師端手動刷新信號（儀表板與數據頁共用，僅在手動按刷新時觸發）。
class TeacherAutoRefreshProvider extends ChangeNotifier {
  int _refreshToken = 0;

  int get refreshToken => _refreshToken;

  /// 手動刷新：通知已訂閱的分頁重新載入資料。
  void forceRefreshNow() {
    _refreshToken += 1;
    notifyListeners();
  }
}
