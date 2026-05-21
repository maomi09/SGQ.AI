import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 學生首次開啟新版本時的使用回饋提示（可跳過、可點連結開啟 Google 表單）。
Future<void> showStudentFeedbackPromptDialog({
  required BuildContext context,
  required String formUrl,
}) async {
  if (!context.mounted) return;

  final linkRecognizer = TapGestureRecognizer()
    ..onTap = () => _openFormUrl(formUrl);

  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('歡迎使用新版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '我們希望了解你使用 SGQ.AI 的體驗。願意花幾分鐘填寫使用回饋問卷嗎？',
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: '表單連結：'),
                    TextSpan(
                      text: formUrl,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer: linkRecognizer,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('稍後再說'),
            ),
            TextButton(
              onPressed: () async {
                await _openFormUrl(formUrl);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: Text(
                '前往填寫',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  } finally {
    linkRecognizer.dispose();
  }
}

Future<void> _openFormUrl(String formUrl) async {
  final uri = Uri.tryParse(formUrl);
  if (uri == null) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
