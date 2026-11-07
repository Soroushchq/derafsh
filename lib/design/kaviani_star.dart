import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Mood of the Kaviani star, mapped from the connection phase.
enum StarMood { dormant, awakening, radiant }

Path _starPath(
  Offset c,
  double rOut,
  double rIn, {
  int points = 8,
  double rot = -math.pi / 2,
}) {
  final p = Path();
  for (var i = 0; i < points * 2; i++) {
    final ang = rot + i * math.pi / points;
    final r = i.isEven ? rOut : rIn;
    final dx = c.dx + math.cos(ang) * r;
    final dy = c.dy + math.sin(ang) * r;
    if (i == 0) {
      p.moveTo(dx, dy);
    } else {
      p.lineTo(dx, dy);
    }
  }
  p.close();
  return p;
}

/// Paints the Kaviani star: an 8-pointed golden star with a diamond core,
/// halo rings (the 'farr') and an unfolding ray crown.
class KavianiStarPainter extends CustomPainter {
  KavianiStarPainter({
    required this.mood,
    required this.spin,
    required this.glow,
    this.unfold = 1.0,
  });

  final StarMood mood;
  final double spin; // 0..1 continuous
  final double glow; // 0..1
  final double unfold; // 0..1 intro progress for rays

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rOut = size.shortestSide * 0.34;

    final baseAlpha = switch (mood) {
      StarMood.dormant => 0.55,
      StarMood.awakening => 0.85,
      StarMood.radiant => 1.0,
    };

    // --- halo rings (the farr) ---
    final ringPaint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.006
      ..color = DrfColors.gold.withValues(alpha: 0.22 * glow + 0.06);
    final ringPaint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.004
      ..color = DrfColors.gold.withValues(alpha: 0.10 * glow + 0.03);
    canvas.drawCircle(c, rOut * 1.34, ringPaint1);
    canvas.drawCircle(c, rOut * 1.55, ringPaint2);

    // dots on the ring
    for (var i = 0; i < 8; i++) {
      final ang = -math.pi / 2 + math.pi / 8 + i * math.pi / 4;
      final d = c + Offset(math.cos(ang), math.sin(ang)) * rOut * 1.34;
      canvas.drawCircle(d, size.shortestSide * 0.008,
          Paint()..color = DrfColors.gold.withValues(alpha: 0.5 * baseAlpha));
    }

    // --- rotating ray crown ---
    final rayAlpha = switch (mood) {
      StarMood.dormant => 0.0,
      StarMood.awakening => 0.55,
      StarMood.radiant => 0.85,
    } *
        unfold;
    if (rayAlpha > 0.01) {
      final speed = switch (mood) {
        StarMood.awakening => 3.0,
        StarMood.radiant => 1.0,
        _ => 0.0,
      };
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(spin * 2 * math.pi * speed);
      for (var i = 0; i < 8; i++) {
        final ang = i * math.pi / 4;
        final rayPath = _rayPath(c, rOut * 1.06, rOut * 1.42, ang);
        canvas.drawPath(
          rayPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.center,
              end: Alignment(
                math.cos(ang),
                math.sin(ang),
              ),
              colors: [
                DrfColors.gold.withValues(alpha: 0),
                DrfColors.goldHi.withValues(alpha: rayAlpha),
              ],
            ).createShader(Rect.fromCircle(center: c, radius: rOut * 1.5)),
        );
      }
      canvas.restore();
    }

    // --- outer glow of the star itself ---
    final glowPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, rOut * 0.22 * glow)
      ..color = DrfColors.gold.withValues(alpha: 0.35 * glow);
    canvas.drawPath(_starPath(c, rOut * 1.02, rOut * 0.45), glowPaint);

    // --- main star body ---
    final star = _starPath(c, rOut, rOut * 0.44);
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(DrfColors.goldHi, DrfColors.gold, 1 - glow)!,
          DrfColors.gold,
          Color.lerp(DrfColors.goldDeep, DrfColors.gold, glow)!,
        ],
      ).createShader(Rect.fromCircle(center: c, radius: rOut));
    canvas.drawPath(star, bodyPaint);
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.005
        ..color = DrfColors.goldRim.withValues(alpha: 0.9),
    );

    // --- diamond core ---
    final core = _starPath(c, rOut * 0.52, rOut * 0.20, points: 4);
    final corePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(DrfColors.cream, DrfColors.goldHi, 1 - glow)!,
          DrfColors.goldHi,
        ],
      ).createShader(Rect.fromCircle(center: c, radius: rOut * 0.55));
    canvas.drawPath(core, corePaint);
    canvas.drawPath(
      core,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.004
        ..color = DrfColors.goldRim.withValues(alpha: 0.8),
    );

    // --- center disc ---
    canvas.drawCircle(
      c,
      rOut * 0.15,
      Paint()..color = DrfColors.goldInkSoft.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      c,
      rOut * 0.09,
      Paint()..color = DrfColors.goldHi.withValues(alpha: 0.95),
    );
  }

  Path _rayPath(Offset c, double r0, double r1, double ang) {
    final dir = Offset(math.cos(ang), math.sin(ang));
    final perp = Offset(-dir.dy, dir.dx);
    final w0 = r1 * 0.055;
    final w1 = r1 * 0.012;
    final a = c + dir * r0 - perp * w0;
    final b = c + dir * r1 - perp * w1;
    final cc = c + dir * r1;
    final d = c + dir * r1 + perp * w1;
    final e = c + dir * r0 + perp * w0;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(cc.dx, cc.dy)
      ..lineTo(d.dx, d.dy)
      ..lineTo(e.dx, e.dy)
      ..close();
  }

  @override
  bool shouldRepaint(covariant KavianiStarPainter oldDelegate) =>
      oldDelegate.mood != mood ||
      oldDelegate.spin != spin ||
      oldDelegate.glow != glow ||
      oldDelegate.unfold != unfold;
}

/// Stateful wrapper providing continuous rotation + breathing glow.
class AnimatedKavianiStar extends StatefulWidget {
  const AnimatedKavianiStar({
    super.key,
    required this.size,
    required this.mood,
    this.unfold = 1.0,
  });

  final double size;
  final StarMood mood;

  /// 0..1 intro progress controlling how much of the ray crown is shown.
  final double unfold;

  @override
  State<AnimatedKavianiStar> createState() => _AnimatedKavianiStarState();
}

class _AnimatedKavianiStarState extends State<AnimatedKavianiStar>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: switch (widget.mood) {
        StarMood.dormant => 0.35,
        StarMood.awakening => 0.72,
        StarMood.radiant => 1.0,
      }),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, glowTarget, _) {
        return AnimatedBuilder(
          animation: Listenable.merge([_spin, _pulse]),
          builder: (context, _) {
            final breath = 0.88 + 0.12 * _pulse.value;
            return CustomPaint(
              size: Size.square(widget.size),
              painter: KavianiStarPainter(
                mood: widget.mood,
                spin: _spin.value,
                glow: (glowTarget * breath).clamp(0.0, 1.0),
                unfold: widget.unfold,
              ),
            );
          },
        );
      },
    );
  }
}
