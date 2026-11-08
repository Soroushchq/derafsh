/// Audit cycle 4 regressions:
/// - B9: PaywallSheet CTA silently did nothing when `launchUrl` returned
///   false (device without a t.me handler); it now shows the same
///   "available in next version" snackbar as the exception path.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
// declared as a dev dependency (already a locked transitive dep of url_launcher)
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:drf/data/drf_source.dart';
import 'package:drf/data/node_resolver.dart';
import 'package:drf/data/usage_ledger.dart';
import 'package:drf/data/remote_config.dart';
import 'package:drf/engine/vpn_engine.dart';
import 'package:drf/state/vpn_controller.dart';
import 'package:drf/core/config.dart';
import 'package:drf/core/strings.dart';
import 'package:drf/ui/advanced_sheet.dart';
import 'package:drf/ui/paywall_sheet.dart';
import 'package:drf/ui/update_gate.dart';

class _FakeLauncher extends UrlLauncherPlatform {
  _FakeLauncher({this.result, this.throwOnLaunch = false});

  final bool? result;
  final bool throwOnLaunch;
  int calls = 0;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    calls++;
    if (throwOnLaunch) throw Exception('no handler');
    return result!;
  }
}

VpnController _controller() => VpnController(
      engine: StubVpnEngine(),
      catalog: SourceCatalog.parse('''
{
  "free_source_id": 1,
  "sources": [
    {"id": 1, "name": "آزاد", "url": "https://example.invalid/free"}
  ]
}
'''),
      nodeResolver: FixedNodeResolver('{}'),
      ledger: UsageLedger(store: MemoryLedgerStore()),
      freeLimit: const Duration(minutes: 30),
    );

Future<void> _pumpPaywall(WidgetTester tester, VpnController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: PaywallSheet(controller: controller)),
    ),
  );
  // let the entrance animations run without pumpAndSettle (the star may
  // animate continuously and never settle)
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('B9: CTA shows feedback when launchUrl returns false',
      (tester) async {
    final fake = _FakeLauncher(result: false);
    final prev = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = fake;
    addTearDown(() => UrlLauncherPlatform.instance = prev);

    final controller = _controller();
    await _pumpPaywall(tester, controller);

    await tester.ensureVisible(find.text(S.paywallCta));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text(S.paywallCta));
    await tester.pump(const Duration(milliseconds: 400));

    expect(fake.calls, 1);
    expect(find.text(S.paywallCtaSoon), findsOneWidget);
  });

  testWidgets('B9: CTA shows feedback when launchUrl throws', (tester) async {
    final fake = _FakeLauncher(throwOnLaunch: true);
    final prev = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = fake;
    addTearDown(() => UrlLauncherPlatform.instance = prev);

    final controller = _controller();
    await _pumpPaywall(tester, controller);

    await tester.ensureVisible(find.text(S.paywallCta));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text(S.paywallCta));
    await tester.pump(const Duration(milliseconds: 400));

    expect(fake.calls, 1);
    expect(find.text(S.paywallCtaSoon), findsOneWidget);
  });

  testWidgets('B9: empty bot_url shows feedback without launching',
      (tester) async {
    final fake = _FakeLauncher(result: true);
    final prev = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = fake;
    addTearDown(() => UrlLauncherPlatform.instance = prev);
    final botBackup = RuntimeConfig.botUrl;
    addTearDown(() => RuntimeConfig.botUrl = botBackup);
    RuntimeConfig.botUrl = '';

    final controller = _controller();
    await _pumpPaywall(tester, controller);

    await tester.ensureVisible(find.text(S.paywallCta));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text(S.paywallCta));
    await tester.pump(const Duration(milliseconds: 400));

    expect(fake.calls, 0, reason: 'nothing to launch — must not call launcher');
    expect(find.text(S.paywallCtaSoon), findsOneWidget);
  });

  group('B10: advanced diagnostics reflect the real update gate', () {
    testWidgets('gate row follows the server min build, not local fallback',
        (tester) async {
      final prev = MandatoryUpdateGate.effectiveMinBuild;
      addTearDown(() => MandatoryUpdateGate.applyServerMinBuild(prev));

      final controller = _controller();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AdvancedSheet(controller: controller)),
        ),
      );

      // local fallback: current build >= min build → pass
      expect(find.text(S.advancedGatePass), findsOneWidget);
      // the build-number row and the min-build row show their constants
      expect(find.text('${Config.buildNumber}'), findsOneWidget);
      expect(find.text('${Config.minRequiredBuild}'), findsOneWidget);

      // server demands a newer build → diagnostics must show blocked
      MandatoryUpdateGate.applyServerMinBuild(999);
      // a static change does not dirty the tree — force a rebuild
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AdvancedSheet(controller: controller)),
        ),
      );

      expect(find.text(S.advancedGateBlock), findsOneWidget);
      expect(find.text('999'), findsOneWidget);
    });
  });
}
