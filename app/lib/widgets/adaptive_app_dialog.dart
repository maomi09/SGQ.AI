import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

/// App 內彈窗：iOS 26+ 使用 Liquid Glass 原生 Alert，其餘平台維持 Material。
abstract final class AdaptiveAppDialog {
  /// 單按鈕通知彈窗（例如：老師回覆、系統提示）。
  static Future<void> showNotify({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = '知道了',
    String? iconSfSymbol,
  }) async {
    if (PlatformInfo.isIOS26OrHigher()) {
      await AdaptiveAlertDialog.show(
        context: context,
        title: title,
        message: message,
        icon: iconSfSymbol ?? 'bell.fill',
        actions: [
          AlertAction(
            title: confirmLabel,
            style: AlertActionStyle.primary,
            onPressed: () {},
          ),
        ],
      );
      return;
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  /// 雙按鈕確認彈窗，回傳 true=確認、false=取消、null=關閉。
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    String? message,
    String cancelLabel = '取消',
    String confirmLabel = '確定',
    bool destructive = false,
    Color? confirmColor,
  }) async {
    if (PlatformInfo.isIOS26OrHigher()) {
      bool? result;
      await AdaptiveAlertDialog.show(
        context: context,
        title: title,
        message: message,
        actions: [
          AlertAction(
            title: cancelLabel,
            style: AlertActionStyle.cancel,
            onPressed: () => result = false,
          ),
          AlertAction(
            title: confirmLabel,
            style: destructive
                ? AlertActionStyle.destructive
                : AlertActionStyle.primary,
            onPressed: () => result = true,
          ),
        ],
      );
      return result;
    }

    if (!context.mounted) return null;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : confirmColor != null
                    ? TextButton.styleFrom(foregroundColor: confirmColor)
                    : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
