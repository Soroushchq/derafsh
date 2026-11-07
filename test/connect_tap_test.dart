import 'package:flutter_test/flutter_test.dart';

import 'package:drf/app.dart';
import 'package:drf/core/persian.dart';
import 'package:drf/core/strings.dart';
import 'package:drf/data/drf_source.dart';
import 'package:drf/data/node_resolver.dart';
import 'package:drf/data/usage_ledger.dart';
import 'package:drf/engine/vpn_engine.dart';
import 'package:drf/state/vpn_controller.dart';

void main() {
  testWidgets('tapping the connect button runs the full connect flow',
      (tester) async {
    final catalog = SourceCatalog.parse('''
    {
      "free_source_id": 1,
      "sources": [
        {"id": 1, "name": "آزاد", "url": "https://example.invalid/free"},
        {"id": 2, "name": "سیمرغ", "url": "https://example.invalid/locked"}
      ]
    }
    ''');
    final controller = VpnController(
      engine: StubVpnEngine(
        connectDelay: const Duration(milliseconds: 100),
        stopDelay: const Duration(milliseconds: 20),
      ),
      catalog: catalog,
      nodeResolver: FixedNodeResolver('{}'),
      ledger: UsageLedger(store: MemoryLedgerStore()),
    );
    await tester.pumpWidget(DerafshApp(controller: controller, showIntro: false));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 300));

    // tap → connecting
    await tester.tap(find.text(S.btnConnect));
    await tester.pump(const Duration(milliseconds: 40));
    expect(controller.phase, VpnPhase.connecting);
    expect(find.text(S.statusConnecting), findsOneWidget);
    expect(find.text(S.btnCancel), findsOneWidget);

    // engine finishes → connected, timer visible
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.phase, VpnPhase.connected);
    expect(find.text('متصل به آزاد'), findsOneWidget);

    // 2s tick → Persian timer text
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(faMmSs(const Duration(seconds: 2))), findsOneWidget);

    // tap again → disconnecting → disconnected
    await tester.tap(find.text(S.btnDisconnect));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.phase, VpnPhase.disconnected);
    expect(find.text(S.btnConnect), findsOneWidget);

    controller.dispose();
  });
}
