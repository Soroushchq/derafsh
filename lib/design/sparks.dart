import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Forge sparks — an homage to Kaveh the Blacksmith. Shown while connecting.
class ForgeSparks extends StatefulWidget {
  const ForgeSparks({
    super.key,
    required this.size,
    this.count = 26,
    this.active = true,
  });

  final double size;
  final int count;
  final bool active;

  @override
  State<ForgeSparks> createState() => _ForgeSparksState();
}

class _ForgeSparksState extends State<ForgeSparks>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _setRunning(widget.active);
  }

  @override
  void didUpdateWidget(covariant ForgeSparks old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _setRunning(widget.active);
  }

  void _setRunning(bool run) {
    if (run) {
      _ctrl.repeat();
    } else {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _SparksPainter(progress: _ctrl.value, count: widget.count),
        ),
      ),
    );
  }
}

class _SparksPainter extends CustomPainter {
  _SparksPainter({required this.progress, required this.count});

  final double progress;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rBase = size.shortestSide * 0.30;
    for (var i = 0; i < count; i++) {
      // Deterministic per-particle parameters.
      final rnd = math.Random(i * 7919);
      final speed = 0.55 + rnd.nextDouble() * 0.9;
      final phase = rnd.nextDouble();
      final angle0 = rnd.nextDouble() * 2 * math.pi;
      final wobbleFreq = 1.5 + rnd.nextDouble() * 2.5;
      final spread = rBase * (0.35 + rnd.nextDouble() * 0.55);
      final dotR = size.shortestSide * (0.004 + rnd.nextDouble() * 0.005);
      final crimson = i % 4 == 0;

      final t = (progress * speed + phase) % 1.0;
      final ang = angle0 + math.sin(t * math.pi * wobbleFreq) * 0.5;
      final radius = rBase + spread * t;
      final d = c + Offset(math.cos(ang), math.sin(ang) * -1) * radius +
          Offset(0, -t * size.shortestSide * 0.12);
      final alpha = math.sin(t * math.pi).clamp(0.0, 1.0);

      canvas.drawCircle(
        d,
        dotR,
        Paint()
          ..color = (crimson ? DrfColors.crimson : DrfColors.goldHi)
              .withValues(alpha: alpha * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparksPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
