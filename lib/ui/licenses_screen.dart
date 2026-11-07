import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';

/// GPLv3 + OFL disclosure screen. Full texts ship inside the binary as
/// assets (assets/legal/*) — GPL §6 compliance for distributed binaries.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DrfColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: DrfColors.text,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          S.licensesTitle,
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _LicenseCard(
            icon: Icons.flag,
            title: S.licensesAppTitle,
            desc: S.licensesAppDesc,
            asset: 'assets/legal/LICENSE.md',
          ),
          const SizedBox(height: 12),
          _LicenseCard(
            icon: Icons.font_download,
            title: S.licensesFontTitle,
            desc: S.licensesFontDesc,
            asset: 'assets/legal/OFL.txt',
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            icon: Icons.hub,
            title: S.licensesEngineTitle,
            desc: S.licensesEngineDesc,
          ),
        ],
      ),
    );
  }
}

class _LicenseCard extends StatelessWidget {
  const _LicenseCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.asset,
  });

  final IconData icon;
  final String title;
  final String desc;
  final String asset;

  Future<void> _openFullText(BuildContext context) async {
    final text = await DefaultAssetBundle.of(context).loadString(asset);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullTextScreen(title: title, text: text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DrfColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DrfColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: DrfColors.gold),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: DrfColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12.5,
              height: 1.8,
              color: DrfColors.textDim,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _openFullText(context),
            child: const Text(
              S.licensesView,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: DrfColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.desc,
  });

  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DrfColors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DrfColors.stroke.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: DrfColors.textFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DrfColors.textDim,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 12,
                    height: 1.7,
                    color: DrfColors.textFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FullTextScreen extends StatelessWidget {
  const _FullTextScreen({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DrfColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: DrfColors.text,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.ltr,
        child: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 11.5,
                  height: 1.55,
                  color: DrfColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
