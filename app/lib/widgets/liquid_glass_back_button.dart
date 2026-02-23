import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// 用於 AppBar 的返回鍵。在 iOS 上使用原生液態玻璃樣式，其餘平台使用 Material 返回鍵。
class LiquidGlassBackButton extends StatelessWidget {
  const LiquidGlassBackButton({
    super.key,
    this.color,
  });

  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS && PlatformVersion.shouldUseNativeGlass) {
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: CNButton.icon(
          icon: CNSymbol('chevron.left', size: 20, color: color),
          config: const CNButtonConfig(style: CNButtonStyle.glass),
          onPressed: () => Navigator.maybePop(context),
        ),
      );
    }
    return IconButton(
      icon: Icon(Icons.arrow_back, color: color ?? const Color(0xFF1F2937)),
      onPressed: () => Navigator.maybePop(context),
    );
  }
}
