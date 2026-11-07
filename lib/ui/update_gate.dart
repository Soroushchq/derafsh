import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../design/kaviani_star.dart';

/// Mandatory-update gate (requirement: after each release the previous
/// version must stop working).
///
/// PART 1: compares against the local [Config.minRequiredBuild] fallback.
/// PART 3: the Worker's /v1/sources returns `min_build`; the fetched value
/// overrides the local one and this gate blocks the whole app — not just
/// the connect button — so an outdated binary can never talk to the infra.
class MandatoryUpdateGate extends StatelessWidget {
  const MandatoryUpdateGate({super.key, required this.child});

  final Widget child;

  static int? _serverMinBuild;

  /// Called by the API layer once the Worker responds.
  static void applyServerMinBuild(int build) {
    _serverMinBuild = build;
  }

  static bool get isBlocked {
    final min = _serverMinBuild ?? Config.minRequiredBuild;
    return Config.buildNumber < min;
  }

  @override
  Widget build(BuildContext context) {
    if (!isBlocked) return child;
    return const _UpdateBlockedScreen();
  }
}

class _UpdateBlockedScreen extends StatelessWidget {
  const _UpdateBlockedScreen();

  Future<void> _onDownload(BuildContext context) async {
    final uri = Uri.parse(Config.updateUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text(S.updateSoon)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text(S.updateSoon)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: DrfGradients.bg),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AnimatedKavianiStar(
                    size: 150,
                    mood: StarMood.dormant,
                    unfold: 0.4,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    S.updateTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: DrfColors.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    S.updateBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 14,
                      height: 1.9,
                      color: DrfColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 240,
                    child: ElevatedButton(
                      onPressed: () => _onDownload(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DrfColors.gold,
                        foregroundColor: DrfColors.goldInk,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        S.updateBtn,
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
