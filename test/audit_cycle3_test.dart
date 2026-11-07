/// Audit cycle 3 regressions:
/// - B7: SourceCatalog.effectiveSource on an empty catalog used to throw
///   StateError (firstWhere / orElse => sources.first); it now returns null.
/// - B8: RuntimeConfig.refresh created an http.Client inline and never
///   closed it (socket/fd leak, same root cause as B3); it now closes the
///   client on every path via try/finally.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:drf/data/drf_source.dart';
import 'package:drf/data/node_resolver.dart';
import 'package:drf/data/remote_config.dart';
import 'package:drf/data/usage_ledger.dart';
import 'package:drf/engine/vpn_engine.dart';
import 'package:drf/state/vpn_controller.dart';

/// http client that records close() so tests can prove the leak is fixed.
class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.response, {this.throwOnSend = false});

  final http.Response? response;
  final bool throwOnSend;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (throwOnSend) throw Exception('network down');
    final r = response!;
    return http.StreamedResponse(
      Stream.value(r.bodyBytes),
      r.statusCode,
      contentLength: r.bodyBytes.length,
      headers: {'content-type': 'application/json'},
    );
  }

  @override
  void close() => closed = true;
}

http.Response _json(Map<String, Object?> body, [int status = 200]) =>
    http.Response.bytes(
      Uint8List.fromList(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('B7: effectiveSource is null-safe on an empty catalog', () {
    test('returns null instead of throwing StateError', () {
      final catalog = SourceCatalog.empty();
      expect(catalog.isEmpty, isTrue);
      // Both of these threw StateError before the fix.
      expect(catalog.effectiveSource(0, true), isNull);
      expect(catalog.effectiveSource(0, false), isNull);
    });

    test('controller reports a clean error on empty catalog', () {
      fakeAsync((async) {
        final c = VpnController(
          engine: StubVpnEngine(),
          catalog: SourceCatalog.empty(),
          nodeResolver: FixedNodeResolver('{}'),
          ledger: UsageLedger(store: MemoryLedgerStore()),
          freeLimit: const Duration(minutes: 30),
        );
        unawaited(c.connect());
        async.elapse(const Duration(milliseconds: 20));
        expect(c.phase, VpnPhase.disconnected);
        expect(c.hasError, isTrue);
        expect(c.effectiveSource, isNull);
        c.dispose();
      });
    });

    test('non-empty catalog keeps its semantics (free pick + clamp)', () {
      final catalog = SourceCatalog.parse('''
{
  "free_source_id": 2,
  "sources": [
    {"id": 1, "name": "A", "url": "https://a"},
    {"id": 2, "name": "B", "url": "https://b"},
    {"id": 3, "name": "C", "url": "https://c"}
  ]
}
''');
      expect(catalog.effectiveSource(0, false)!.id, 2); // free tier → free id
      expect(catalog.effectiveSource(5, true)!.id, 3); // clamp to last
      expect(catalog.effectiveSource(-1, true)!.id, 1); // clamp to first
      expect(catalog[0].locked, isTrue);
      expect(catalog[1].locked, isFalse); // free id never locked
    });
  });

  group('B8: RuntimeConfig.refresh closes its http client', () {
    String botBackup() => RuntimeConfig.botUrl;

    test('success path: bot applied and client closed', () async {
      final before = botBackup();
      addTearDown(() => RuntimeConfig.botUrl = before);
      final fake = _RecordingClient(
        _json({'ok': true, 'bot_url': 'https://t.me/RealBot'}),
      );
      RuntimeConfig.clientFactory = () => fake;
      addTearDown(() => RuntimeConfig.clientFactory = null);

      await RuntimeConfig.refresh();

      expect(fake.closed, isTrue, reason: 'client must be closed on success');
      expect(RuntimeConfig.botUrl, 'https://t.me/RealBot');
    });

    test('error path: refresh never throws and still closes', () async {
      final fake = _RecordingClient(null, throwOnSend: true);
      RuntimeConfig.clientFactory = () => fake;
      addTearDown(() => RuntimeConfig.clientFactory = null);

      await expectLater(RuntimeConfig.refresh(), completes);
      expect(fake.closed, isTrue, reason: 'client must be closed on error');
    });

    test('input validation: bot_url outside t.me is rejected', () async {
      final before = botBackup();
      addTearDown(() => RuntimeConfig.botUrl = before);
      final fake = _RecordingClient(
        _json({'ok': true, 'bot_url': 'https://evil.example/bot'}),
      );
      RuntimeConfig.clientFactory = () => fake;
      addTearDown(() => RuntimeConfig.clientFactory = null);

      await RuntimeConfig.refresh();

      expect(RuntimeConfig.botUrl, before);
      expect(fake.closed, isTrue);
    });

    test('non-2xx: nothing applied, client closed', () async {
      final before = botBackup();
      addTearDown(() => RuntimeConfig.botUrl = before);
      final fake = _RecordingClient(_json({'ok': true}, 500));
      RuntimeConfig.clientFactory = () => fake;
      addTearDown(() => RuntimeConfig.clientFactory = null);

      await RuntimeConfig.refresh();

      expect(RuntimeConfig.botUrl, before);
      expect(fake.closed, isTrue);
    });
  });
}
