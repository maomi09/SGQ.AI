import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 可愛貓咪動畫 loading 指示器（給學生端/老師端共用）
class CuteLoadingIndicator extends StatefulWidget {
  final String label;

  const CuteLoadingIndicator({
    super.key,
    required this.label,
  });

  @override
  State<CuteLoadingIndicator> createState() => _CuteLoadingIndicatorState();
}

class _CuteLoadingIndicatorState extends State<CuteLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * math.pi;
        final o1 = 0.4 + 0.6 * ((math.sin(t) + 1) / 2);
        final o2 = 0.4 + 0.6 * ((math.sin(t + 0.8) + 1) / 2);
        final o3 = 0.4 + 0.6 * ((math.sin(t + 1.6) + 1) / 2);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: o1,
                  child: const Icon(Icons.pets, size: 24, color: Colors.orange),
                ),
                const SizedBox(width: 8),
                Opacity(
                  opacity: o2,
                  child: const Icon(Icons.pets, size: 24, color: Colors.orange),
                ),
                const SizedBox(width: 8),
                Opacity(
                  opacity: o3,
                  child: const Icon(Icons.pets, size: 24, color: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

