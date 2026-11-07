import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/demo_sources.dart';

/// A single VPN source card. Locked sources dim out with a painted lock and
/// open the paywall on tap (handled by the parent).
class SourceCard extends StatelessWidget {
  const SourceCard({
    super.key,
    required this.source,
    required this.index,
    required this.selected,
    required this.connected,
    required this.onTap,
  });

  final DrfSource source;
  final int index;
  final bool selected;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = source.locked;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: 108,
        decoration: BoxDecoration(
          color: selected && !locked
              ? DrfColors.surfaceHi
              : DrfColors.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected && !locked
                ? DrfColors.gold
                : locked
                    ? DrfColors.stroke.withValues(alpha: 0.6)
                    : DrfColors.stroke,
            width: selected && !locked ? 1.6 : 1,
          ),
          boxShadow: selected && connected && !locked
              ? [
                  BoxShadow(
                    color: DrfColors.gold.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // painted glyph: a small ring/dot mark
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: locked
                          ? DrfColors.textFaint.withValues(alpha: 0.5)
                          : DrfColors.gold.withValues(alpha: 0.8),
                      width: 2,
                    ),
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: locked
                        ? DrfColors.textFaint.withValues(alpha: 0.4)
                        : DrfColors.gold,
                  ),
                ),
                if (locked)
                  Positioned(
                    bottom: -2,
                    left: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: DrfColors.bgBottom,
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 11,
                        color: DrfColors.crimson,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              source.name,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: locked ? DrfColors.textFaint : DrfColors.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              locked ? 'پرمیوم' : S.connectedSource,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 10,
                color: locked
                    ? DrfColors.crimson.withValues(alpha: 0.85)
                    : DrfColors.gold.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
