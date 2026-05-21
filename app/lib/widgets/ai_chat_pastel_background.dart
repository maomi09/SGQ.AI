import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// 粉彩聊天背景色盤（漸層 + 光暈色）。
class ChatPastelPalette {
  const ChatPastelPalette({
    required this.gradientA,
    required this.gradientB,
    required this.gradientMidA,
    required this.gradientMidB,
    required this.gradientEnd,
    required this.halo1,
    required this.halo2,
    required this.halo3,
    required this.accent,
    required this.accentSoft,
  });

  final Color gradientA;
  final Color gradientB;
  final Color gradientMidA;
  final Color gradientMidB;
  final Color gradientEnd;
  final Color halo1;
  final Color halo2;
  final Color halo3;
  final Color accent;
  final Color accentSoft;

  static const ai = ChatPastelPalette(
    gradientA: Color(0xFFE8E4F5),
    gradientB: Color(0xFFF5E6EE),
    gradientMidA: Color(0xFFF0E8F4),
    gradientMidB: Color(0xFFE3F4F8),
    gradientEnd: Color(0xFFFAFBFF),
    halo1: Color(0xFFD4C4F0),
    halo2: Color(0xFFF8C8DC),
    halo3: Color(0xFFB8E4F0),
    accent: Color(0xFF7B6FD6),
    accentSoft: Color(0xFFB8AEE8),
  );

  /// 師生聊天室：淺藍色系。
  static const teacherStudent = ChatPastelPalette(
    gradientA: Color(0xFFE3F2FC),
    gradientB: Color(0xFFD6EBFA),
    gradientMidA: Color(0xFFE8F4FC),
    gradientMidB: Color(0xFFCEE9F8),
    gradientEnd: Color(0xFFF8FCFF),
    halo1: Color(0xFFA8D4F0),
    halo2: Color(0xFF7EC8E8),
    halo3: Color(0xFFB5E3F7),
    accent: Color(0xFF3B8DD4),
    accentSoft: Color(0xFF9ED0EF),
  );
}

/// 粉彩動態背景（可切換色盤）。
class ChatPastelBackground extends StatefulWidget {
  const ChatPastelBackground({
    super.key,
    this.palette = ChatPastelPalette.ai,
  });

  final ChatPastelPalette palette;

  @override
  State<ChatPastelBackground> createState() => _ChatPastelBackgroundState();
}

/// AI 聊天室背景（淡紫／粉／青）。
class AiChatPastelBackground extends StatelessWidget {
  const AiChatPastelBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatPastelBackground();
  }
}

class _ChatPastelBackgroundState extends State<ChatPastelBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final shift = math.sin(t * math.pi * 2) * 0.5 + 0.5;

        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final haloDiameter = math.max(w, h) * 1.12;

            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(
                        -0.75 + shift * 0.55,
                        -1.0 + math.cos(t * math.pi * 2) * 0.18,
                      ),
                      end: Alignment(
                        1.0 - shift * 0.4,
                        1.05,
                      ),
                      colors: [
                        Color.lerp(palette.gradientA, palette.gradientB, shift)!,
                        Color.lerp(
                          palette.gradientMidA,
                          palette.gradientMidB,
                          1 - shift * 0.45,
                        )!,
                        palette.gradientEnd,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                ..._haloLayers(
                  palette: palette,
                  t: t,
                  width: w,
                  height: h,
                  haloDiameter: haloDiameter,
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _haloLayers({
    required ChatPastelPalette palette,
    required double t,
    required double width,
    required double height,
    required double haloDiameter,
  }) {
    Widget layer({
      required double phase,
      required Color color,
      required double anchorX,
      required double anchorY,
      required double diameterScale,
    }) {
      final pulse = 0.55 + 0.45 * math.sin((t + phase) * math.pi * 2);
      final driftX = math.sin((t + phase) * math.pi * 2) * 0.14;
      final driftY = math.cos((t + phase * 0.65) * math.pi * 2) * 0.12;
      final diameter = haloDiameter * diameterScale;
      final left = width * (anchorX + driftX) - diameter / 2;
      final top = height * (anchorY + driftY) - diameter / 2;

      return Positioned(
        left: left,
        top: top,
        width: diameter,
        height: diameter,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.72 * pulse),
                  color.withValues(alpha: 0.42 * pulse),
                  color.withValues(alpha: 0.12 * pulse),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.14, 0.32, 0.48],
              ),
            ),
          ),
        ),
      );
    }

    return [
      layer(
        phase: 0,
        color: palette.halo1,
        anchorX: 0.22,
        anchorY: 0.2,
        diameterScale: 0.92,
      ),
      layer(
        phase: 0.33,
        color: palette.halo2,
        anchorX: 0.78,
        anchorY: 0.28,
        diameterScale: 0.95,
      ),
      layer(
        phase: 0.66,
        color: palette.halo3,
        anchorX: 0.48,
        anchorY: 0.72,
        diameterScale: 0.98,
      ),
    ];
  }
}

/// 聊天室共用視覺（毛玻璃、氣泡、卡片）。
abstract final class ChatUiTheme {
  static const Color textPrimary = Color(0xFF2D3142);
  static const Color textSecondary = Color(0xFF6B7280);
  static const double radiusCard = 22;
  static const double radiusPill = 28;

  static Widget glassPanel({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    bool showBottomDivider = false,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            border: showBottomDivider
                ? Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  )
                : null,
          ),
          child: child,
        ),
      ),
    );
  }

  static Widget messageBubble({
    required Widget child,
    required bool isUser,
    required bool isSystem,
    required Color accent,
    double? maxWidth,
    double? width,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 14),
    BoxBorder? border,
  }) {
    final borderRadius = BorderRadius.circular(
      isSystem ? radiusPill : radiusCard,
    );
    final fillAlpha = isSystem ? 0.38 : (isUser ? 0.42 : 0.48);
    final borderAlpha = isSystem ? 0.72 : 0.62;

    return Container(
      margin: margin,
      width: width,
      constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth) : null,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSystem ? 16 : 14,
              vertical: isSystem ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: fillAlpha),
              borderRadius: borderRadius,
              border: border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: borderAlpha),
                    width: 1,
                  ),
              boxShadow: [
                BoxShadow(
                  color: (isUser ? accent : Colors.black).withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  static BoxDecoration listCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  static InputDecoration pillInputDecoration({
    required String hintText,
    required Color accent,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusPill),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusPill),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusPill),
        borderSide: BorderSide(
          color: accent.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      filled: true,
      fillColor: Colors.white,
    );
  }

  static Widget circleIconButton({
    required IconData icon,
    required Color accent,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: accent,
          style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
        ),
      ),
    );
  }
}

/// AI 聊天室視覺常數（相容舊引用）。
abstract final class AiChatTheme {
  static const Color textPrimary = ChatUiTheme.textPrimary;
  static const Color textSecondary = ChatUiTheme.textSecondary;
  static const Color accent = Color(0xFF7B6FD6);
  static const Color accentSoft = Color(0xFFB8AEE8);
  static const double radiusCard = ChatUiTheme.radiusCard;
  static const double radiusPill = ChatUiTheme.radiusPill;

  static Widget glassPanel({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    bool showBottomDivider = false,
  }) =>
      ChatUiTheme.glassPanel(
        child: child,
        borderRadius: borderRadius,
        padding: padding,
        showBottomDivider: showBottomDivider,
      );

  static Widget messageBubble({
    required Widget child,
    required bool isUser,
    required bool isSystem,
    double? maxWidth,
  }) =>
      ChatUiTheme.messageBubble(
        child: child,
        isUser: isUser,
        isSystem: isSystem,
        accent: accent,
        maxWidth: maxWidth,
      );

  static BoxDecoration questionCardDecoration() => ChatUiTheme.listCardDecoration();
}

/// 師生聊天室視覺常數（淺藍色系）。
abstract final class TeacherStudentChatTheme {
  static const ChatPastelPalette palette = ChatPastelPalette.teacherStudent;
  static const Color textPrimary = ChatUiTheme.textPrimary;
  static const Color textSecondary = ChatUiTheme.textSecondary;
  static Color get accent => palette.accent;
  static Color get accentSoft => palette.accentSoft;
  static const double radiusCard = ChatUiTheme.radiusCard;
  static const double radiusPill = ChatUiTheme.radiusPill;

  static Widget messageBubble({
    required Widget child,
    required bool isUser,
    double? maxWidth,
    double? width,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 8),
    BoxBorder? border,
  }) =>
      ChatUiTheme.messageBubble(
        child: child,
        isUser: isUser,
        isSystem: false,
        accent: accent,
        maxWidth: maxWidth,
        width: width,
        margin: margin,
        border: border,
      );
}
