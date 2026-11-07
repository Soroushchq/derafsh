import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../state/vpn_controller.dart';
import 'update_gate.dart';

/// Hidden diagnostics panel — opens after tapping the version label
/// five times on the home screen.
class AdvancedSheet extends StatelessWidget {
  const AdvancedSheet({super.key, required this.controller});

  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    // Diagnostics must reflect the REAL gate (including a server-provided
    // min build), not just the local fallback constants.
    final gatePass = !MandatoryUpdateGate.isBlocked;

    return Container(
      decoration: const BoxDecoration(
        color: DrfColors.bgTop,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: DrfColors.stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            S.advancedTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: DrfColors.text,
            ),
          ),
          const SizedBox(height: 16),
          _Row(label: S.advancedRowVersion, value: Config.appVersion),
          _Row(label: S.advancedRowBuild, value: '${Config.buildNumber}'),
          _Row(label: S.advancedRowEngine, value: controller.engine.label),
          _Row(
            label: S.advancedRowMinBuild,
            value: '${MandatoryUpdateGate.effectiveMinBuild}',
          ),
          _Row(
            label: S.advancedRowGate,
            value: gatePass ? S.advancedGatePass : S.advancedGateBlock,
            good: gatePass,
          ),
          _Row(
            label: S.advancedRowDevice,
            value: S.advancedDevicePlaceholder,
          ),
          const SizedBox(height: 12),
          Text(
            S.advancedFooter,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11,
              color: DrfColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.good});

  final String label;
  final String value;
  final bool? good;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 13,
                color: DrfColors.textDim,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: good == null
                  ? DrfColors.text
                  : (good! ? DrfColors.gold : DrfColors.crimson),
            ),
          ),
        ],
      ),
    );
  }
}
