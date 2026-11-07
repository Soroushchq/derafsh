import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The big golden CTA with a periodic sheen sweep and press feedback.
class ShineButton extends StatefulWidget {
  const ShineButton({
    super.key,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.crimson = false,
    this.height = 64,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool crimson;
  final double height;

  @override
  State<ShineButton> createState() => _ShineButtonState();
}

class _ShineButtonState extends State<ShineButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  bool _pressed = false;

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = widget.crimson || !widget.enabled
        ? (widget.enabled
            ? const [Color(0xFFE06A7F), DrfColors.crimson, DrfColors.crimsonDeep]
            : const [Color(0xFF4A3668), Color(0xFF3A2A55)])
        : const [DrfColors.goldHi, DrfColors.gold, Color(0xFFC08A29)];

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (widget.enabled) widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.height / 2),
            gradient: LinearGradient(colors: colors),
            boxShadow: [
              BoxShadow(
                color: (widget.crimson || !widget.enabled
                        ? DrfColors.crimson
                        : DrfColors.gold)
                    .withValues(alpha: widget.enabled ? 0.35 : 0.15),
                blurRadius: 26,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  child: AnimatedBuilder(
                    animation: _sheen,
                    builder: (context, _) => Align(
                      alignment: Alignment(-3 + 6 * _sheen.value, 0),
                      child: Transform.rotate(
                        angle: 0.4,
                        child: Container(
                          width: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.28),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: widget.enabled
                        ? DrfColors.goldInk
                        : DrfColors.textFaint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
