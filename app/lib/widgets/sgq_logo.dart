import 'package:flutter/material.dart';

/// SGQ App 圖示（與啟動過場、登入頁共用）。
class SgqLogo extends StatelessWidget {
  const SgqLogo({
    super.key,
    this.size = 112,
    this.showShadow = true,
  });

  static const String assetPath = 'assets/icon/app_icon.png';

  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    // 避免外層 Column(stretch) 把寬度拉滿導致圖示被壓扁成橢圓
    return Align(
      alignment: Alignment.center,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: Colors.green.shade200.withValues(alpha: 0.45),
                      blurRadius: size * 0.25,
                      offset: Offset(0, size * 0.09),
                    ),
                  ]
                : null,
          ),
          child: ClipOval(
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.school_rounded,
                size: size * 0.5,
                color: Colors.green.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
