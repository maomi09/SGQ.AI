import 'package:flutter/material.dart';
import 'sgq_logo.dart';

/// 啟動時還原登入狀態的過場：顯示 SGQ logo 與淡入／呼吸動畫。
class SgqAuthBootstrapScreen extends StatefulWidget {
  const SgqAuthBootstrapScreen({super.key});

  @override
  State<SgqAuthBootstrapScreen> createState() => _SgqAuthBootstrapScreenState();
}

class _SgqAuthBootstrapScreenState extends State<SgqAuthBootstrapScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _pulseController;
  late final Animation<double> _enterOpacity;
  late final Animation<double> _enterScale;
  late final Animation<double> _pulseScale;
  late final Animation<double> _titleOpacity;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _enterOpacity = CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOut,
    );
    _enterScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
      ),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _enterController.forward().whenComplete(() {
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _enterController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade50,
              Colors.green.shade100,
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_enterController, _pulseController]),
            builder: (context, _) {
              final scale = _enterScale.value * _pulseScale.value;
              return Opacity(
                opacity: _enterOpacity.value,
                child: Transform.scale(
                  scale: scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SgqLogo(size: 112),
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: _titleOpacity.value,
                        child: const Text(
                          'SGQ AI',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: _titleOpacity.value * 0.85,
                        child: Text(
                          '學習系統',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
