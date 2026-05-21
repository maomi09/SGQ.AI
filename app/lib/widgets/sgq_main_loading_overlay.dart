import 'package:flutter/material.dart';
import 'sgq_logo.dart';

/// 主畫面初始化全螢幕遮罩：與啟動過場一致的漸層 + logo 呼吸動畫。
class SgqMainLoadingOverlay extends StatefulWidget {
  const SgqMainLoadingOverlay({
    super.key,
    this.message = '載入中...',
  });

  final String message;

  @override
  State<SgqMainLoadingOverlay> createState() => _SgqMainLoadingOverlayState();
}

class _SgqMainLoadingOverlayState extends State<SgqMainLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _fadeOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.96, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeOpacity = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade50,
                Colors.green.shade100,
                Colors.white.withValues(alpha: 0.94),
              ],
            ),
          ),
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeOpacity.value,
                  child: Transform.scale(
                    scale: _pulseScale.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SgqLogo(size: 88),
                  const SizedBox(height: 22),
                  Text(
                    widget.message,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
