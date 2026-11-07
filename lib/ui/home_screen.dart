import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/persian.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../design/kaviani_star.dart';
import '../design/shine_button.dart';
import '../design/stagger_in.dart';
import '../design/sparks.dart';
import '../state/vpn_controller.dart';
import 'advanced_sheet.dart';
import 'licenses_screen.dart';
import 'paywall_sheet.dart';
import 'widgets/source_card.dart';
import 'widgets/usage_strip.dart';

/// The single screen of Derafsh: one big connect button, the Kaviani star,
/// sources and the hidden advanced panel.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final VpnController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _versionTaps = 0;
  VpnPhase _prevPhase = VpnPhase.disconnected;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final c = widget.controller;
    if (c.hasError && _prevPhase == VpnPhase.connecting) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(S.errorConnect)));
    }
    if (c.phase != VpnPhase.connecting) {
      // consume sticky error once leaving the connecting phase
      c.hasError = false;
    }
    if (c.consumeTimeoutFlag()) {
      _showTimedOutDialog();
    }
    _prevPhase = c.phase;
  }

  void _showTimedOutDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: DrfColors.surfaceHi,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          S.timedOutTitle,
          style: TextStyle(
              fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          S.timedOutBody,
          style: const TextStyle(
              fontFamily: 'Vazirmatn', fontSize: 14, color: DrfColors.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(S.timedOutOk),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _openPaywall();
            },
            child: const Text(
              S.timedOutPremium,
              style: TextStyle(color: DrfColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  void _openPaywall() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => PaywallSheet(controller: widget.controller),
    );
  }

  void _openAdvanced() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => AdvancedSheet(controller: widget.controller),
    );
  }

  void _onVersionTap() {
    _versionTaps++;
    if (_versionTaps >= 5) {
      _versionTaps = 0;
      _openAdvanced();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole screen whenever the controller notifies: phase
    // changes, the 1s session tick, and premium-flag changes.
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final c = widget.controller;
    final connected = c.phase == VpnPhase.connected;
    final connecting = c.phase == VpnPhase.connecting;
    final disconnecting = c.phase == VpnPhase.disconnecting;

    final mood = switch (c.phase) {
      VpnPhase.disconnected => StarMood.dormant,
      VpnPhase.connecting => StarMood.awakening,
      VpnPhase.connected => StarMood.radiant,
      VpnPhase.disconnecting => StarMood.dormant,
    };

    final buttonLabel = switch (c.phase) {
      VpnPhase.disconnected => S.btnConnect,
      VpnPhase.connecting => S.btnCancel,
      VpnPhase.connected => S.btnDisconnect,
      VpnPhase.disconnecting => S.btnDisconnect,
    };

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: DrfGradients.bg),
        child: SafeArea(
          child: Column(
            children: [
              // ---------- header ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: StaggerIn(
                  index: 0,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: AnimatedKavianiStar(
                          size: 30,
                          mood: connected ? StarMood.radiant : StarMood.dormant,
                          unfold: 0.9,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            S.appName,
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: DrfColors.text,
                            ),
                          ),
                          Text(
                            S.tagline,
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 11,
                              color: DrfColors.textDim,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _AccountChip(premium: c.premium),
                    ],
                  ),
                ),
              ),

              // ---------- star + status ----------
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // farr glow backdrop
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 600),
                        opacity: connected ? 0.9 : (connecting ? 0.5 : 0.25),
                        child: Container(
                          width: 340,
                          height: 340,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: DrfGradients.farr,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 270,
                                height: 270,
                                child: ForgeSparks(
                                  size: 270,
                                  active: connecting,
                                ),
                              ),
                              AnimatedKavianiStar(
                                size: 250,
                                mood: mood,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // status line + timer (mood applied below)
                          _StatusBlock(
                            connected: connected,
                            connecting: connecting,
                            disconnecting: disconnecting,
                            statusText: connecting
                                ? S.statusConnecting
                                : disconnecting
                                    ? S.statusDisconnecting
                                    : connected
                                        ? '${S.statusConnectedTo} '
                                            '${c.activeSourceName.isEmpty ? S.defaultSourceName : c.activeSourceName}'
                                        : S.statusDisconnected,
                            elapsed: c.elapsed,
                            premium: c.premium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ---------- usage strip (free only) ----------
              if (!c.premium)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: StaggerIn(
                    index: 1,
                    child: UsageStrip(
                      remaining: c.freeRemaining,
                      total: c.freeLimit,
                    ),
                  ),
                ),

              // ---------- sources ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: StaggerIn(
                  index: 2,
                  child: Row(
                    children: [
                      const Text(
                        S.sourcesTitle,
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: DrfColors.text,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        c.catalog.isEmpty
                            ? S.sourcesEmpty
                            : activeCountLabel(1, c.catalog.length),
                        style: const TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 12,
                          color: DrfColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 118,
                child: StaggerIn(
                  index: 3,
                  child: c.catalog.isEmpty
                      ? Center(
                          child: Text(
                            S.sourcesEmpty,
                            style: const TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 13,
                              color: DrfColors.textFaint,
                            ),
                          ),
                        )
                      : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: c.catalog.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final s = c.catalog[i];
                      return SourceCard(
                        source: s,
                        index: i,
                        selected: c.selectedSource == i,
                        connected: connected,
                        onTap: () {
                          if (s.locked) {
                            _openPaywall();
                          } else {
                            c.selectSource(i);
                          }
                        },
                      );
                    },
                  ),
                ),
              ),

              // ---------- CTA ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: StaggerIn(
                  index: 4,
                  child: ShineButton(
                    label: buttonLabel,
                    enabled: !disconnecting,
                    crimson: connecting || connected || disconnecting,
                    onTap: () {
                      if (connected || connecting) {
                        c.disconnect();
                      } else {
                        c.connect();
                      }
                    },
                  ),
                ),
              ),

              // ---------- upsell line ----------
              if (!c.premium)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: StaggerIn(
                    index: 5,
                    child: GestureDetector(
                      onTap: _openPaywall,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 15,
                            color: DrfColors.gold.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            S.upgradeLine,
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: DrfColors.gold,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ---------- footer ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: StaggerIn(
                  index: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _onVersionTap,
                        child: Text(
                          'نسخه ${faNum(Config.appVersion)} (${faInt(Config.buildNumber)})',
                          style: const TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 11,
                            color: DrfColors.textFaint,
                          ),
                        ),
                      ),
                      TextSpanButton(
                        label: ' • ${S.openLicenses}',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LicensesScreen(),
                          ),
                        ),
                      ),
                    ],
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

/// Status line + timer, kept together so the hero block scales as one.
class _StatusBlock extends StatelessWidget {
  const _StatusBlock({
    required this.connected,
    required this.connecting,
    required this.disconnecting,
    required this.statusText,
    required this.elapsed,
    required this.premium,
  });

  final bool connected;
  final bool connecting;
  final bool disconnecting;
  final String statusText;
  final Duration elapsed;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            statusText,
            key: ValueKey<String>(statusText),
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: connected ? DrfColors.gold : DrfColors.textDim,
            ),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: connected
              ? Directionality(
                  key: const ValueKey<String>('timer'),
                  textDirection: TextDirection.ltr,
                  child: Text(
                    faMmSs(elapsed),
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 40,
                      fontWeight: FontWeight.w300,
                      color: DrfColors.text,
                      letterSpacing: 3,
                    ),
                  ),
                )
              : Text(
                  premium ? S.unlimited : '',
                  key: const ValueKey<String>('idle'),
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 15,
                    color: DrfColors.textFaint,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Tiny text-button helper for the footer link.
class TextSpanButton extends StatelessWidget {
  const TextSpanButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 11,
          color: DrfColors.gold,
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.premium});

  final bool premium;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: premium
            ? DrfColors.gold.withValues(alpha: 0.16)
            : DrfColors.surface.withValues(alpha: 0.8),
        border: Border.all(
          color: premium ? DrfColors.gold : DrfColors.stroke,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            premium ? Icons.workspace_premium : Icons.bolt,
            size: 14,
            color: premium ? DrfColors.gold : DrfColors.textDim,
          ),
          const SizedBox(width: 5),
          Text(
            premium ? S.chipPremium : S.chipFree,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: premium ? DrfColors.gold : DrfColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}
