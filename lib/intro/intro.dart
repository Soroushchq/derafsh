import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../design/kaviani_star.dart';

/// Animated Kaviani intro: the star rises out of the void, rays unfold,
/// the name appears — then the overlay yields to the home screen.
class IntroOverlay extends StatefulWidget {
  const IntroOverlay({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<IntroOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: widget.onDone,
        child: Container(
          color: DrfColors.bg,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = _ctrl.value;
              final exit = Curves.easeInCubic
                  .transform(((t - 0.86) / 0.14).clamp(0.0, 1.0));
              final starT = Curves.easeOutCubic.transform(
                ((t - 0.04) / 0.5).clamp(0.0, 1.0),
              );
              final unfold = Curves.easeOutBack.transform(
                ((t - 0.34) / 0.42).clamp(0.0, 1.0),
              );
              final titleT = Curves.easeOut.transform(
                ((t - 0.52) / 0.26).clamp(0.0, 1.0),
              );

              return Opacity(
                opacity: 1 - exit,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // rotating halo arcs behind the star
                    CustomPaint(
                      size: const Size(360, 360),
                      painter: HaloPaint(
                        progress: t,
                        alpha: 0.35 * starT * (1 - exit),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: 0.55 + 0.45 * starT,
                          child: Opacity(
                            opacity: starT,
                            child: AnimatedKavianiStar(
                              size: 240,
                              mood: StarMood.awakening,
                              unfold: unfold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Opacity(
                          opacity: titleT,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - titleT)),
                            child: Text(
                              S.appName,
                              style: const TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                color: DrfColors.text,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: titleT,
                          child: Text(
                            S.tagline,
                            style: const TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 15,
                              color: DrfColors.textDim,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 42,
                      child: Opacity(
                        opacity: 0.45 * (1 - exit),
                        child: Text(
                          S.introSkip,
                          style: const TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 12,
                            color: DrfColors.textFaint,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Rotating halo used behind the intro title (subtle motion, deterministic).
class HaloPaint extends CustomPainter {
  HaloPaint({required this.progress, required this.alpha});

  final double progress;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.42;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = DrfColors.gold.withValues(alpha: alpha);
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r + i * 10),
        progress * 2 * math.pi * (i.isEven ? 1 : -1),
        math.pi * 0.6,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HaloPaint oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.alpha != alpha;
}
