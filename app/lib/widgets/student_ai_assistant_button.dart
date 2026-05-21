import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_chat_settings_provider.dart';
import '../screens/chatgpt/chatgpt_chat_screen.dart';
import 'adaptive_app_dialog.dart';
import 'ai_assistant_icon.dart';

/// 學生端 AI 小幫手按鈕：一律顯示；老師關閉時點擊顯示提示，不開啟聊天室。
class StudentAiAssistantIconButton extends StatelessWidget {
  const StudentAiAssistantIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const AiAssistantIcon(),
      tooltip: 'AI 小幫手',
      onPressed: () => openStudentAiAssistantOrShowDisabled(context),
    );
  }
}

Future<void> openStudentAiAssistantOrShowDisabled(BuildContext context) async {
  final aiSettings = Provider.of<AiChatSettingsProvider>(context, listen: false);
  if (!aiSettings.isEnabled) {
    await AdaptiveAppDialog.showNotify(
      context: context,
      title: 'AI 功能目前已關閉',
      message: '老師已關閉 AI 小幫手，目前無法使用。',
      iconSfSymbol: 'sparkles.slash',
    );
    return;
  }
  if (!context.mounted) return;
  showChatDialog(context);
}
