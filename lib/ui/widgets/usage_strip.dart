import 'package:flutter/material.dart';

import '../../core/persian.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';

/// Free-tier usage bar: gold draining to crimson as the daily quota is spent.
class UsageStrip extends StatelessWidget {
  const UsageStrip({
    super.key,
    required this.remaining,
    required this.total,
  });

  final Duration remaining;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final fraction =
        total.inSeconds <= 0 ? 0.0 : remaining.inSeconds / total.inSeconds;
    final low = fraction < 0.17;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: fraction.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, f, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: DrfColors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DrfColors.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    S.usageTitle,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13,
                      color: DrfColors.textDim,
                    ),
                  ),
                  const Spacer(),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      faMmSs(remaining),
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: low ? DrfColors.crimson : DrfColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: f,
                  minHeight: 6,
                  backgroundColor: DrfColors.stroke,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.lerp(DrfColors.crimson, DrfColors.gold, f)!,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
