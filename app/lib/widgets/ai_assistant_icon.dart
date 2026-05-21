import 'package:flutter/material.dart';

/// AI 小幫手統一圖示（三顆星芒／sparkles 樣式）。
class AiAssistantIcon extends StatelessWidget {
  const AiAssistantIcon({
    super.key,
    this.size = 24,
    this.color,
  });

  final double size;
  final Color? color;

  static Color defaultColor(BuildContext context) => Colors.blue.shade600;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.auto_awesome,
      size: size,
      color: color ?? defaultColor(context),
    );
  }
}
