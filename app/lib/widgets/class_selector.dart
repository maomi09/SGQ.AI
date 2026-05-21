import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';
import '../providers/class_provider.dart';

/// 與學生分頁背景相近的按鈕底色。
abstract final class ClassSelectorColors {
  static Color get unselectedFill => Colors.green.shade100;
  static Color get selectedFill => Colors.amber.shade200;
  static const Color label = Color(0xFF1F2937);
  static Color get border => Colors.green.shade200;
}

/// 代表「所有班級」的選單值。
const String kAllClassesMenuValue = '__all_classes__';

/// 非 iOS 26：點擊按鈕後以對話框選擇班級。
Future<String?> showClassPickerDialog(
  BuildContext context, {
  bool includeAllClasses = true,
}) async {
  final classProvider = Provider.of<ClassProvider>(context, listen: false);
  final classes = classProvider.classes;

  if (classes.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('目前沒有可選擇的班級'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
    return null;
  }

  final selectedClassId = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text('選擇班級'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: includeAllClasses ? classes.length + 1 : classes.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (includeAllClasses && index == 0) {
              final isSelected = classProvider.selectedClass == null;
              return ListTile(
                title: const Text('所有班級'),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: Colors.green.shade600)
                    : null,
                onTap: () => Navigator.pop(dialogContext, kAllClassesMenuValue),
              );
            }
            final classIndex = includeAllClasses ? index - 1 : index;
            final classModel = classes[classIndex];
            final isSelected = classProvider.selectedClass?.id == classModel.id;
            return ListTile(
              title: Text(classModel.name),
              subtitle: Text('班級代碼：${classModel.code}'),
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: Colors.green.shade600)
                  : null,
              onTap: () => Navigator.pop(dialogContext, classModel.id),
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

  return selectedClassId;
}

/// 班級選擇按鈕（樣式與學生端課程選擇按鈕一致）。
///
/// iOS 26+：一般按鈕外觀 + Liquid Glass 原生彈出選單。
/// 其餘平台：同色系按鈕 + 選班級對話框。
class ClassSelectorCard extends StatelessWidget {
  const ClassSelectorCard({
    super.key,
    required this.selectedClass,
    required this.onClassSelected,
    this.emptyHint = '請選擇班級',
    this.inHeader = false,
    this.includeAllClasses = true,
  });

  final ClassModel? selectedClass;
  final Future<void> Function(String? classId) onClassSelected;
  final String emptyHint;
  final bool inHeader;
  final bool includeAllClasses;

  void _showEmptyClassesMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('目前沒有可選擇的班級'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _handleIos26Selection(String? value) async {
    if (value == null || value.isEmpty) return;
    if (value == kAllClassesMenuValue) {
      await onClassSelected(null);
    } else {
      await onClassSelected(value);
    }
  }

  List<AdaptivePopupMenuEntry> _buildIos26MenuItems(
    List<ClassModel> classes,
    String? selectedId,
  ) {
    final items = <AdaptivePopupMenuEntry>[];
    if (includeAllClasses) {
      items.add(
        AdaptivePopupMenuItem<String>(
          label: '所有班級',
          value: kAllClassesMenuValue,
          icon: selectedId == null ? 'checkmark' : null,
        ),
      );
    }
    items.addAll(
      classes.map(
        (c) => AdaptivePopupMenuItem<String>(
          label: '${c.name}（${c.code}）',
          value: c.id,
          icon: selectedId == c.id ? 'checkmark' : null,
        ),
      ),
    );
    return items;
  }

  Future<void> _pickWithDialog(BuildContext context) async {
    final classId = await showClassPickerDialog(
      context,
      includeAllClasses: includeAllClasses,
    );
    if (classId == null) return;
    if (classId == kAllClassesMenuValue) {
      await onClassSelected(null);
    } else {
      await onClassSelected(classId);
    }
  }

  Widget _buildButtonFace({
    required bool hasSelection,
    required String tooltip,
  }) {
    final icon = hasSelection ? Icons.groups : Icons.groups_outlined;

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
              ? ClassSelectorColors.selectedFill
              : ClassSelectorColors.unselectedFill,
          borderRadius: BorderRadius.circular(hasSelection ? 20 : 16),
          border: Border.all(
            color: ClassSelectorColors.border,
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
          color: ClassSelectorColors.label,
        ),
      ),
    );
  }

  Widget _buildIos26Button(BuildContext context, List<ClassModel> classes) {
    final hasSelection = selectedClass != null;
    final face = _buildButtonFace(
      hasSelection: hasSelection,
      tooltip: selectedClass != null ? selectedClass!.name : emptyHint,
    );

    if (classes.isEmpty) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEmptyClassesMessage(context),
          borderRadius: BorderRadius.circular(16),
          child: face,
        ),
      );
    }

    // 按鈕維持自訂外觀（plain）；彈出選單為 iOS 26 原生 Liquid Glass
    return AdaptivePopupMenuButton.widget<String>(
      buttonStyle: PopupButtonStyle.plain,
      items: _buildIos26MenuItems(classes, selectedClass?.id),
      onSelected: (_, entry) {
        _handleIos26Selection(entry.value);
      },
      child: face,
    );
  }

  Widget _buildMaterialButton(BuildContext context) {
    final hasSelection = selectedClass != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pickWithDialog(context),
        borderRadius: BorderRadius.circular(hasSelection ? 20 : 16),
        child: _buildButtonFace(
          hasSelection: hasSelection,
          tooltip: selectedClass != null ? selectedClass!.name : emptyHint,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<ClassProvider>().classes;

    final Widget button = PlatformInfo.isIOS26OrHigher()
        ? _buildIos26Button(context, classes)
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
