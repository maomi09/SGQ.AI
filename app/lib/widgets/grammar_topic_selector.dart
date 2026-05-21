import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/grammar_topic_model.dart';
import '../providers/grammar_topic_provider.dart';

/// 與學生分頁背景相近的按鈕底色。
abstract final class GrammarTopicSelectorColors {
  static Color get unselectedFill => Colors.green.shade100;
  static Color get selectedFill => Colors.amber.shade200;
  static const Color label = Color(0xFF1F2937);
  static Color get border => Colors.green.shade200;
}

/// 非 iOS 26：點擊按鈕後以對話框選擇課程。
Future<String?> showGrammarTopicPickerDialog(BuildContext context) async {
  final grammarTopicProvider =
      Provider.of<GrammarTopicProvider>(context, listen: false);
  final topics = grammarTopicProvider.topics;

  if (topics.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('目前沒有可選擇的課程'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
    return null;
  }

  final selectedTopicId = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text('選擇課程'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: topics.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final topic = topics[index];
            final isSelected =
                grammarTopicProvider.selectedTopic?.id == topic.id;
            return ListTile(
              title: Text(topic.title),
              subtitle: topic.description.isNotEmpty
                  ? Text(
                      topic.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: Colors.green.shade600)
                  : null,
              onTap: () => Navigator.pop(dialogContext, topic.id),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
      ],
    ),
  );

  return selectedTopicId;
}

/// 文法主題選擇按鈕。
///
/// iOS 26+：按鈕外觀貼近背景色，點擊開啟 Liquid Glass 原生選單。
/// 其餘平台：同色系按鈕 + 選課程對話框。
class GrammarTopicSelectorCard extends StatelessWidget {
  const GrammarTopicSelectorCard({
    super.key,
    required this.selectedTopic,
    required this.onTopicSelected,
    this.emptyHint = '請選擇文法主題',
    this.inHeader = false,
  });

  final GrammarTopicModel? selectedTopic;
  final Future<void> Function(String topicId) onTopicSelected;
  final String emptyHint;
  final bool inHeader;

  Future<void> _pickWithDialog(BuildContext context) async {
    final topicId = await showGrammarTopicPickerDialog(context);
    if (topicId == null) return;
    await onTopicSelected(topicId);
  }

  void _showEmptyTopicsMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('目前沒有可選擇的課程'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  List<AdaptivePopupMenuEntry> _buildIos26MenuItems(
    List<GrammarTopicModel> topics,
    String? selectedId,
  ) {
    return topics
        .map(
          (topic) => AdaptivePopupMenuItem<String>(
            label: topic.title,
            value: topic.id,
            icon: selectedId == topic.id ? 'checkmark' : null,
          ),
        )
        .toList();
  }

  Widget _buildButtonFace({
    required bool hasSelection,
    required String tooltip,
  }) {
    final icon = hasSelection ? Icons.menu_book : Icons.menu_book_outlined;

    return Tooltip(
      message: tooltip,
      child: Container(
        width: inHeader ? null : double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: inHeader ? 12 : 16,
          vertical: inHeader ? 10 : 14,
        ),
        decoration: BoxDecoration(
          color: hasSelection
              ? GrammarTopicSelectorColors.selectedFill
              : GrammarTopicSelectorColors.unselectedFill,
          borderRadius: BorderRadius.circular(hasSelection ? 20 : 16),
          border: Border.all(
            color: GrammarTopicSelectorColors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: inHeader ? 22 : 26,
          color: GrammarTopicSelectorColors.label,
        ),
      ),
    );
  }

  String get _tooltipMessage =>
      selectedTopic != null ? selectedTopic!.title : emptyHint;

  Widget _buildIos26Button(BuildContext context, List<GrammarTopicModel> topics) {
    final hasSelection = selectedTopic != null;
    final face = _buildButtonFace(
      hasSelection: hasSelection,
      tooltip: _tooltipMessage,
    );

    if (topics.isEmpty) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEmptyTopicsMessage(context),
          borderRadius: BorderRadius.circular(16),
          child: face,
        ),
      );
    }

    return AdaptivePopupMenuButton.widget<String>(
      buttonStyle: PopupButtonStyle.glass,
      tint: GrammarTopicSelectorColors.unselectedFill,
      items: _buildIos26MenuItems(topics, selectedTopic?.id),
      onSelected: (_, entry) {
        final topicId = entry.value;
        if (topicId != null && topicId.isNotEmpty) {
          onTopicSelected(topicId);
        }
      },
      child: face,
    );
  }

  Widget _buildMaterialButton(BuildContext context) {
    final hasSelection = selectedTopic != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pickWithDialog(context),
        borderRadius: BorderRadius.circular(hasSelection ? 20 : 16),
        child: _buildButtonFace(
          hasSelection: hasSelection,
          tooltip: _tooltipMessage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topics = context.watch<GrammarTopicProvider>().topics;

    final Widget button = PlatformInfo.isIOS26OrHigher()
        ? _buildIos26Button(context, topics)
        : _buildMaterialButton(context);

    if (inHeader) {
      return button;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: button,
    );
  }
}
