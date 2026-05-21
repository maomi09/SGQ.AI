import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 以白色為主的動態漸層與柔和光暈背景（學生端 AI 聊天室等）。
class AnimatedWhiteBackground extends StatefulWidget {
  const AnimatedWhiteBackground({super.key});

  @override
  State<AnimatedWhiteBackground> createState() => _AnimatedWhiteBackgroundState();
}

class _AnimatedWhiteBackgroundState extends State<AnimatedWhiteBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
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
      builder: (context, child) {
        final t = _controller.value;
        final shift = math.sin(t * math.pi * 2) * 0.5 + 0.5;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(
                -0.7 + shift * 0.5,
                -1.0 + math.cos(t * math.pi * 2) * 0.15,
              ),
              end: Alignment(
                1.0 - shift * 0.35,
                1.0,
              ),
              colors: [
                Color.lerp(Colors.white, const Color(0xFFF7FBF8), shift)!,
                Color.lerp(
                  const Color(0xFFFAFCFA),
                  Colors.white,
                  1 - shift * 0.6,
                )!,
                Colors.white,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: CustomPaint(
            painter: _AnimatedWhiteBlobsPainter(phase: t),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _AnimatedWhiteBlobsPainter extends CustomPainter {
  _AnimatedWhiteBlobsPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    void drawBlob({
      required double baseX,
      required double baseY,
      required double radius,
      required Color color,
      required double drift,
    }) {
      final x = size.width * baseX +
          math.sin((phase + drift) * math.pi * 2) * size.width * 0.05;
      final y = size.height * baseY +
          math.cos((phase + drift * 0.7) * math.pi * 2) * size.height * 0.04;
      final paint = Paint()..color = color;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    drawBlob(
      baseX: 0.12,
      baseY: 0.1,
      radius: size.shortestSide * 0.26,
      color: Colors.green.shade100.withValues(alpha: 0.28),
      drift: 0.0,
    );
    drawBlob(
      baseX: 0.88,
      baseY: 0.18,
      radius: size.shortestSide * 0.2,
      color: Colors.grey.shade200.withValues(alpha: 0.35),
      drift: 0.33,
    );
    drawBlob(
      baseX: 0.55,
      baseY: 0.82,
      radius: size.shortestSide * 0.3,
      color: Colors.green.shade50.withValues(alpha: 0.4),
      drift: 0.66,
    );
  }

  @override
  bool shouldRepaint(covariant _AnimatedWhiteBlobsPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}
