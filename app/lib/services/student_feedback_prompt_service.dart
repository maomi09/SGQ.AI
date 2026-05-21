import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// 依 App 版本決定是否顯示學生回饋問卷彈窗（每個版本僅提示一次）。
abstract final class StudentFeedbackPromptService {
  static const String _dismissedVersionKey =
      'student_feedback_prompt_dismissed_version';

  static Future<bool> shouldShowPrompt() async {
    final url = AppConfig.studentFeedbackFormUrl.trim();
    if (url.isEmpty) return false;

    final packageInfo = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();
    final dismissedVersion = prefs.getString(_dismissedVersionKey);
    return dismissedVersion != packageInfo.version;
  }

  static Future<void> markPromptHandledForCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, packageInfo.version);
  }
}
