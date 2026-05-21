import 'dart:ui';

import 'package:flutter/material.dart';

/// 單一分頁項目（圖示 + 標籤）。
class SgqFloatingGlassTabItem {
  const SgqFloatingGlassTabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Android 用浮動毛玻璃底部分頁列（對齊影片中的 pill + 滑動高亮效果）。
class SgqFloatingGlassTabBar extends StatelessWidget {
  const SgqFloatingGlassTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.horizontalMargin = 16,
    this.bottomMargin = 12,
  });

  final List<SgqFloatingGlassTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double horizontalMargin;
  final double bottomMargin;

  static const Color activeColor = Color(0xFFC4A574);
  static const Color inactiveColor = Color(0xFF3D3D3D);
  static const Duration _indicatorDuration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalMargin,
        0,
        horizontalMargin,
        bottomMargin,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.82),
                  width: 1,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemCount = items.length;
                  if (itemCount == 0) {
                    return const SizedBox.shrink();
                  }
                  final itemWidth = constraints.maxWidth / itemCount;
                  const indicatorInset = 6.0;

                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: _indicatorDuration,
                        curve: Curves.easeInOutCubic,
                        left: currentIndex * itemWidth + indicatorInset,
                        width: itemWidth - indicatorInset * 2,
                        top: indicatorInset,
                        bottom: indicatorInset,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.65),
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(itemCount, (index) {
                          final selected = index == currentIndex;
                          final item = items[index];
                          final color = selected ? activeColor : inactiveColor;

                          return Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => onTap(index),
                                borderRadius: BorderRadius.circular(26),
                                splashColor: activeColor.withValues(alpha: 0.12),
                                highlightColor: activeColor.withValues(alpha: 0.08),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        selected ? item.activeIcon : item.icon,
                                        size: 22,
                                        color: color,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10,
                                          height: 1.1,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
