import 'package:flutter_test/flutter_test.dart';

import 'package:drf/app.dart';
import 'package:drf/core/strings.dart';
import 'package:drf/engine/vpn_engine.dart';
import 'package:drf/state/vpn_controller.dart';

void main() {
  testWidgets('home screen renders core elements', (tester) async {
    final controller = VpnController(
      engine: StubVpnEngine(connectDelay: const Duration(milliseconds: 10)),
    );
    await tester.pumpWidget(DerafshApp(controller: controller, showIntro: false));
    // let the staggered entrances run
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(S.appName), findsOneWidget);
    expect(find.text(S.btnConnect), findsOneWidget);
    expect(find.text(S.sourcesTitle), findsOneWidget);
    expect(find.text(S.usageTitle), findsOneWidget);
    expect(find.text(S.chipFree), findsOneWidget);
    controller.dispose();
  });

  testWidgets('tapping a locked source opens the paywall', (tester) async {
    final controller = VpnController(
      engine: StubVpnEngine(connectDelay: const Duration(milliseconds: 10)),
    );
    await tester.pumpWidget(DerafshApp(controller: controller, showIntro: false));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('سیمرغ'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(S.paywallTitle), findsOneWidget);
    expect(find.text(S.paywallCta), findsOneWidget);
    controller.dispose();
  });
}
