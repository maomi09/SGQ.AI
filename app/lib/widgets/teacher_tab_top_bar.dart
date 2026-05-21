import 'package:flutter/material.dart';
import '../models/class_model.dart';
import 'class_selector.dart';

/// 老師分頁頂部列：班級選擇按鈕、班級名稱、右側工具按鈕。
class TeacherTabTopBar extends StatelessWidget {
  const TeacherTabTopBar({
    super.key,
    required this.selectedClass,
    required this.onClassSelected,
    required this.trailing,
    this.emptyTitleHint = '所有班級',
    this.includeAllClasses = true,
  });

  final ClassModel? selectedClass;
  final Future<void> Function(String? classId) onClassSelected;
  final Widget trailing;
  final String emptyTitleHint;
  final bool includeAllClasses;

  @override
  Widget build(BuildContext context) {
    final title = selectedClass?.name ?? emptyTitleHint;
    final hasSelection = selectedClass != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClassSelectorCard(
            inHeader: true,
            selectedClass: selectedClass,
            onClassSelected: onClassSelected,
            includeAllClasses: includeAllClasses,
            emptyHint: emptyTitleHint,
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
