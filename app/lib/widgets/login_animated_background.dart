import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 登入頁動態漸層與浮動光暈背景。
class LoginAnimatedBackground extends StatefulWidget {
  const LoginAnimatedBackground({super.key});

  @override
  State<LoginAnimatedBackground> createState() =>
      _LoginAnimatedBackgroundState();
}

class _LoginAnimatedBackgroundState extends State<LoginAnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
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
                -0.8 + shift * 0.6,
                -1.0 + math.cos(t * math.pi * 2) * 0.2,
              ),
              end: Alignment(
                1.0 - shift * 0.4,
                1.0,
              ),
              colors: [
                Color.lerp(Colors.green.shade50, Colors.green.shade100, shift)!,
                Color.lerp(
                  Colors.green.shade100,
                  const Color(0xFFE8F5E9),
                  1 - shift * 0.5,
                )!,
                Colors.white,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: CustomPaint(
            painter: _LoginBackgroundBlobsPainter(phase: t),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _LoginBackgroundBlobsPainter extends CustomPainter {
  _LoginBackgroundBlobsPainter({required this.phase});

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
          math.sin((phase + drift) * math.pi * 2) * size.width * 0.06;
      final y = size.height * baseY +
          math.cos((phase + drift * 0.7) * math.pi * 2) * size.height * 0.05;
      final paint = Paint()..color = color;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    drawBlob(
      baseX: 0.15,
      baseY: 0.12,
      radius: size.shortestSide * 0.28,
      color: Colors.green.shade200.withValues(alpha: 0.35),
      drift: 0.0,
    );
    drawBlob(
      baseX: 0.85,
      baseY: 0.22,
      radius: size.shortestSide * 0.22,
      color: Colors.teal.shade100.withValues(alpha: 0.4),
      drift: 0.33,
    );
    drawBlob(
      baseX: 0.5,
      baseY: 0.78,
      radius: size.shortestSide * 0.32,
      color: Colors.green.shade100.withValues(alpha: 0.45),
      drift: 0.66,
    );
  }

  @override
  bool shouldRepaint(covariant _LoginBackgroundBlobsPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}
