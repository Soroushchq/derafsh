/// Tests for bugs found & fixed in audit cycle 1.
///
/// B1: manual disconnect lost the last 0-4s of free usage.
/// B2: a native drop (tunnel dying) never reached the controller, so the UI
///     stayed "connected" and the quota kept ticking.
/// B3: SingBoxNodeResolver never closed its http.Client.
/// B6: freeRemaining started at the full limit on app restart even when the
///     persisted rolling-window usage said otherwise.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:drf/data/drf_source.dart';
import 'package:drf/data/node_resolver.dart';
import 'package:drf/data/usage_ledger.dart';
import 'package:drf/engine/vpn_engine.dart';
import 'package:drf/state/vpn_controller.dart';

SourceCatalog _catalog() => SourceCatalog.parse('''
{
  "free_source_id": 1,
  "sources": [
    {"id": 1, "name": "آزاد", "url": "https://example.invalid/free"}
  ]
}
''');

/// Engine with an injectable native-event stream (stands in for libbox).
class FakeNativeEngine implements VpnEngine {
  final eventsController = StreamController<Map<Object?, Object?>>.broadcast();

  @override
  Stream<Map<Object?, Object?>>? get stateEvents => eventsController.stream;

  @override
  String get label => 'fake-native';

  @override
  Future<void> start(String config) async {}

  @override
  Future<void> stop() async {}
}

VpnController _controller({required VpnEngine engine, UsageLedger? ledger}) {
  return VpnController(
    engine: engine,
    catalog: _catalog(),
    nodeResolver: FixedNodeResolver('{}'),
    ledger: ledger ?? UsageLedger(store: MemoryLedgerStore()),
    freeLimit: const Duration(minutes: 30),
  );
}

void main() {
  test('B6: freeRemaining is initialized from the persisted ledger', () async {
    final store = MemoryLedgerStore();
    final pre = UsageLedger(store: store);
    await pre.addSeconds(10 * 60, now: DateTime.now()); // 10 minutes used

    final c = _controller(
      engine: StubVpnEngine(),
      ledger: UsageLedger(store: store),
    );

    // _initLedger runs from the constructor (async): let it finish.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(c.freeRemaining, const Duration(minutes: 20));
    expect(c.phase, VpnPhase.disconnected);
    c.dispose();
  });

  test('B1: manual disconnect flushes pending seconds to the ledger', () async {
    final store = MemoryLedgerStore();
    final ledger = UsageLedger(store: store);
    final c = _controller(
      engine: StubVpnEngine(
        connectDelay: Duration.zero,
        stopDelay: Duration.zero,
      ),
      ledger: ledger,
    );
    await Future<void>.delayed(Duration.zero);

    await c.connect();
    expect(c.phase, VpnPhase.connected);

    // 3 seconds of session time — below the 5s batching threshold.
    for (var i = 0; i < 3; i++) {
      c.debugTick();
    }
    expect(ledger.usedSeconds(), 0, reason: 'batching must not have flushed');

    await c.disconnect();
    expect(ledger.usedSeconds(), 3,
        reason: 'manual disconnect must flush pending seconds');
    c.dispose();
  });

  test('B2: native drop moves the controller to disconnected and flushes',
      () async {
    final store = MemoryLedgerStore();
    final ledger = UsageLedger(store: store);
    final engine = FakeNativeEngine();
    final c = _controller(engine: engine, ledger: ledger);
    await Future<void>.delayed(Duration.zero);

    await c.connect();
    expect(c.phase, VpnPhase.connected);

    c.debugTick();
    c.debugTick();

    // Tunnel dies out-of-band: native pushes a disconnected event.
    engine.eventsController
        .add(<Object?, Object?>{'state': 'disconnected', 'error': 'tunnel died'});
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(c.phase, VpnPhase.disconnected);
    expect(c.hasError, isTrue);
    expect(c.lastErrorMessage, 'tunnel died');
    expect(ledger.usedSeconds(), 2, reason: 'the drop must flush pending usage');
    c.dispose();
  });

  test('B2: user-initiated disconnect is not double-handled by the event',
      () async {
    final engine = FakeNativeEngine();
    final c = _controller(engine: engine);
    await Future<void>.delayed(Duration.zero);

    await c.connect();
    final disconnected = c.disconnect();
    // native confirms the stop right after we asked for it
    engine.eventsController.add(<Object?, Object?>{'state': 'disconnected'});
    await disconnected;
    await Future<void>.delayed(Duration.zero);

    expect(c.phase, VpnPhase.disconnected);
    expect(c.hasError, isFalse,
        reason: 'own disconnect must not surface as an error');
    c.dispose();
  });

  test('B3: dispose closes the underlying http client', () async {
    final client = RecordingClient();
    final resolver = SingBoxNodeResolver(client: client);
    resolver.dispose();
    expect(client.closed, isTrue);
  });
}

class RecordingClient implements http.Client {
  bool closed = false;

  @override
  void close() {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
