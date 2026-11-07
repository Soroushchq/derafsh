import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drf/data/drf_source.dart';
import 'package:drf/data/node_resolver.dart';
import 'package:drf/data/usage_ledger.dart';
import 'package:drf/engine/vpn_engine.dart';
import 'package:drf/state/vpn_controller.dart';
import 'package:drf/ui/update_gate.dart';

SourceCatalog _catalog() => SourceCatalog.parse('''
{
  "free_source_id": 1,
  "sources": [
    {"id": 1, "name": "آزاد", "url": "https://example.invalid/free"}
  ]
}
''');

VpnController _c({
  required Duration freeLimit,
  bool premium = false,
  bool failConnect = false,
}) {
  return VpnController(
    engine: StubVpnEngine(
      connectDelay: const Duration(milliseconds: 10),
      stopDelay: const Duration(milliseconds: 5),
      failConnect: failConnect,
    ),
    catalog: _catalog(),
    nodeResolver: FixedNodeResolver('{}'),
    ledger: UsageLedger(store: MemoryLedgerStore()),
    freeLimit: freeLimit,
    premium: premium,
  );
}

void main() {
  test('connect succeeds and ticks elapsed time', () {
    fakeAsync((async) {
      final c = _c(freeLimit: const Duration(minutes: 30));
      unawaited(c.connect());
      expect(c.phase, VpnPhase.connecting);
      async.elapse(const Duration(milliseconds: 30));
      expect(c.phase, VpnPhase.connected);
      async.elapse(const Duration(seconds: 3));
      expect(c.elapsed, const Duration(seconds: 3));
      c.dispose();
    });
  });

  test('free quota timeout auto-disconnects and flags', () {
    fakeAsync((async) {
      final c = _c(freeLimit: const Duration(seconds: 5));
      unawaited(c.connect());
      async.elapse(const Duration(milliseconds: 30));
      expect(c.phase, VpnPhase.connected);
      async.elapse(const Duration(seconds: 5));
      async.elapse(const Duration(milliseconds: 20));
      expect(c.phase, VpnPhase.disconnected);
      expect(c.freeRemaining, Duration.zero);
      expect(c.timedOutLastSession, isTrue);
      expect(c.consumeTimeoutFlag(), isTrue);
      expect(c.consumeTimeoutFlag(), isFalse);
      c.dispose();
    });
  });

  test('premium never times out', () {
    fakeAsync((async) {
      final c = _c(freeLimit: const Duration(seconds: 5), premium: true);
      unawaited(c.connect());
      async.elapse(const Duration(milliseconds: 30));
      async.elapse(const Duration(seconds: 60));
      expect(c.phase, VpnPhase.connected);
      expect(c.freeRemaining, const Duration(seconds: 5));
      c.dispose();
    });
  });

  test('engine failure surfaces as error state', () {
    fakeAsync((async) {
      final c = _c(
        freeLimit: const Duration(minutes: 30),
        failConnect: true,
      );
      unawaited(c.connect());
      async.elapse(const Duration(milliseconds: 30));
      expect(c.phase, VpnPhase.disconnected);
      expect(c.hasError, isTrue);
      c.dispose();
    });
  });

  test('update gate blocks older builds', () {
    MandatoryUpdateGate.applyServerMinBuild(99);
    expect(MandatoryUpdateGate.isBlocked, isTrue);
    MandatoryUpdateGate.applyServerMinBuild(1);
    expect(MandatoryUpdateGate.isBlocked, isFalse);
  });
}
