import 'package:flutter/material.dart';
import '../models/grammar_topic_model.dart';
import 'grammar_topic_selector.dart';

/// 學生分頁頂部列：課程選擇按鈕、課程標題、右側工具按鈕。
class StudentTabTopBar extends StatelessWidget {
  const StudentTabTopBar({
    super.key,
    required this.selectedTopic,
    required this.onTopicSelected,
    required this.trailing,
    this.emptyTitleHint = '請選擇文法主題',
  });

  final GrammarTopicModel? selectedTopic;
  final Future<void> Function(String topicId) onTopicSelected;
  final Widget trailing;
  final String emptyTitleHint;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedTopic != null;
    final title = hasSelection ? selectedTopic!.title : emptyTitleHint;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GrammarTopicSelectorCard(
            inHeader: true,
            selectedTopic: selectedTopic,
            onTopicSelected: onTopicSelected,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: hasSelection ? 18 : 16,
                fontWeight: hasSelection ? FontWeight.bold : FontWeight.w500,
                color: hasSelection
                    ? const Color(0xFF1F2937)
                    : Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
