import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiChatSettingsProvider with ChangeNotifier {
  static const _kEnableAiChatKey = 'enable_ai_chat';

  bool _isEnabled = true;
  bool _isLoaded = false;

  bool get isEnabled => _isEnabled;
  bool get isLoaded => _isLoaded;

  AiChatSettingsProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_kEnableAiChatKey) ?? true;
    } catch (_) {
      _isEnabled = true;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    _isEnabled = !_isEnabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnableAiChatKey, _isEnabled);
    } catch (_) {
      // 寫入失敗時保留記憶體中的狀態，稍後可重新開啟 App 重新載入
    }
  }
}

