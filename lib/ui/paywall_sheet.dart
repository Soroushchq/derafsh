import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../data/remote_config.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../design/kaviani_star.dart';
import '../design/shine_button.dart';
import '../state/vpn_controller.dart';

/// Premium paywall — the only monetisation surface of the app.
///
/// Persuasion structure (see requirement: convince that premium is cheaper
/// and more convenient):
///   1. the maths (30 min/day ≈ 15 h/month vs unlimited ≈ 720 h/month)
///   2. a tight comparison table
///   3. a dead-simple 4-step activation
///   4. single-device binding reassurance
class PaywallSheet extends StatelessWidget {
  const PaywallSheet({super.key, required this.controller});

  final VpnController controller;

  Future<void> _onCta(BuildContext context) async {
    final botUrl = RuntimeConfig.botUrl;
    if (botUrl.isEmpty) {
      _showCtaFallback(context);
      return;
    }
    final uri = Uri.parse(botUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!context.mounted) return;
      if (!launched) _showCtaFallback(context);
    } catch (_) {
      if (!context.mounted) return;
      // no handler for t.me links on this device (or plugin missing)
      _showCtaFallback(context);
    }
  }

  void _showCtaFallback(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(S.paywallCtaSoon)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: DrfColors.bgTop,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: DrfColors.stroke, width: 1),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: DrfColors.stroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // title row with mini radiant star
              Row(
                children: [
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: AnimatedKavianiStar(
                      size: 34,
                      mood: StarMood.radiant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    S.paywallTitle,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: DrfColors.text,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close,
                        size: 20, color: DrfColors.textFaint),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                S.paywallHeadline,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 15,
                  height: 1.7,
                  color: DrfColors.textDim,
                ),
              ),
              const SizedBox(height: 16),

              // ---- the maths ----
              const _MathCard(),
              const SizedBox(height: 16),

              // ---- comparison ----
              const Text(
                S.paywallCompareTitle,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: DrfColors.text,
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(S.paywallRows.length, (i) {
                return _CompareRow(index: i, row: S.paywallRows[i]);
              }),
              const SizedBox(height: 20),

              // ---- price ----
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      DrfColors.gold.withValues(alpha: 0.12),
                      DrfColors.gold.withValues(alpha: 0.04),
                    ],
                  ),
                  border: Border.all(
                    color: DrfColors.gold.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      Config.priceLabel,
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: DrfColors.gold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      S.paywallPunch,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        color: DrfColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ---- steps ----
              const Text(
                S.paywallStepTitle,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: DrfColors.text,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(4, (i) {
                final steps = [
                  S.paywallStep1,
                  S.paywallStep2,
                  S.paywallStep3,
                  S.paywallStep4,
                ];
                return _StepRow(index: i, label: steps[i]);
              }),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.verified_user,
                      size: 14, color: DrfColors.violet),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      S.paywallBindNote,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 11.5,
                        color: DrfColors.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ---- CTA ----
              ShineButton(
                label: S.paywallCta,
                onTap: () => _onCta(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MathCard extends StatelessWidget {
  const _MathCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DrfColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DrfColors.stroke),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_bottom,
                  size: 15, color: DrfColors.crimson),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  S.paywallMathFree,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13,
                    color: DrfColors.textDim,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.all_inclusive,
                  size: 17, color: DrfColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  S.paywallMathPremium,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: DrfColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.index, required this.row});

  final int index;
  final (String, String, String) row;

  @override
  Widget build(BuildContext context) {
    final (feature, freeVal, premiumVal) = row;
    final sameValue = freeVal == premiumVal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _DelayedEntrance(
        delayMs: 60 * index,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: DrfColors.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  feature,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 12.5,
                    color: DrfColors.textDim,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: _ValueCell(
                  text: freeVal,
                  good: sameValue,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _ValueCell(
                  text: premiumVal,
                  good: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({required this.text, required this.good});

  final String text;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final color = good ? DrfColors.gold : DrfColors.crimson;
    return Row(
      children: [
        Icon(
          good ? Icons.check_circle : Icons.cancel,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11.5,
              fontWeight: good ? FontWeight.w700 : FontWeight.w400,
              color: good ? DrfColors.text : DrfColors.textFaint,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.label});

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _DelayedEntrance(
        delayMs: 70 * index,
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: DrfColors.gold,
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: DrfColors.goldInk,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 13,
                  color: DrfColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DelayedEntrance extends StatelessWidget {
  const _DelayedEntrance({required this.delayMs, required this.child});

  final int delayMs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 320 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}
