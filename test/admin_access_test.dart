/// Admin mode (v1.0.2): owner code gate + unlocked entitlements.
///
/// The real admin code never appears in this repository — tests exercise
/// the hash comparison with locally computed digests.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drf/data/admin_store.dart';
import 'package:drf/data/drf_source.dart';
import 'package:drf/data/node_resolver.dart';
import 'package:drf/data/usage_ledger.dart';
import 'package:drf/engine/vpn_engine.dart';
import 'package:drf/state/vpn_controller.dart';

final String _testCodeHash =
    sha256.convert(utf8.encode('correct-code')).toString();

SourceCatalog _catalog() => SourceCatalog.parse(
      '''
{
  "version": 1,
  "free_source_id": 1,
  "sources": [
    {"id": 1, "name": "A", "url": "https://a.example/sub"},
    {"id": 2, "name": "B", "url": "https://b.example/sub"},
    {"id": 3, "name": "C", "url": "https://c.example/sub"}
  ]
}
''',
    );

VpnController _controller({
  bool premium = false,
  MemoryAdminStore? adminStore,
}) {
  return VpnController(
    engine: UnsupportedEngine('test'),
    catalog: _catalog(),
    nodeResolver: FixedNodeResolver('{}'),
    ledger: UsageLedger(store: MemoryLedgerStore()),
    premium: premium,
    adminStore: adminStore,
  );
}

void main() {
  group('adminCodeMatches', () {
    test('accepts the exact code and trims whitespace', () {
      expect(adminCodeMatches('correct-code', _testCodeHash), isTrue);
      expect(adminCodeMatches('  correct-code  ', _testCodeHash), isTrue);
    });

    test('rejects wrong codes and empty input', () {
      expect(adminCodeMatches('wrong-code', _testCodeHash), isFalse);
      expect(adminCodeMatches('', _testCodeHash), isFalse);
      expect(adminCodeMatches('  ', _testCodeHash), isFalse);
    });
  });

  group('admin entitlements', () {
    test('admin unlocks every source without premium', () async {
      final c = _controller();
      addTearDown(c.dispose);
      await c.debugWaitAdminInit();

      expect(c.unlocked, isFalse);
      await c.setAdmin(true);
      expect(c.admin, isTrue);
      expect(c.unlocked, isTrue);

      // a premium-locked index becomes the effective source
      c.selectSource(1);
      expect(c.effectiveSource?.id, 2);
    });

    test('admin removes the free-quota consumption', () async {
      final c = _controller();
      addTearDown(c.dispose);
      await c.debugWaitAdminInit();

      await c.setAdmin(true);
      expect(c.freeRemaining, c.freeLimit);
      for (var i = 0; i < 10; i++) {
        c.debugTick();
      }
      expect(c.freeRemaining, c.freeLimit);
      // no usage recorded for admin sessions
      expect(c.ledger.usedSeconds(), 0);
    });

    test('non-admin still consumes the quota (regression guard)', () async {
      final c = _controller();
      addTearDown(c.dispose);
      await c.debugWaitAdminInit();

      for (var i = 0; i < 10; i++) {
        c.debugTick();
      }
      expect(c.freeRemaining.inSeconds, c.freeLimit.inSeconds - 10);
    });

    test('setAdmin persists into the store and can be revoked', () async {
      final store = MemoryAdminStore();
      final c = _controller(adminStore: store);
      addTearDown(c.dispose);
      await c.debugWaitAdminInit();

      await c.setAdmin(true);
      expect(await store.read(), isTrue);

      await c.setAdmin(false);
      expect(await store.read(), isFalse);
      expect(c.admin, isFalse);
      expect(c.unlocked, isFalse);
    });

    test('persisted flag is restored on next start', () async {
      final store = MemoryAdminStore();
      await store.write(true);

      final c = _controller(adminStore: store);
      addTearDown(c.dispose);
      await c.debugWaitAdminInit();

      expect(c.admin, isTrue);
      expect(c.unlocked, isTrue);
      // the free strip is hidden for an admin right from startup
      expect(c.freeRemaining, c.freeLimit);
    });
  });

  group('admin store', () {
    test('memory store starts false and round-trips', () async {
      final store = MemoryAdminStore();
      expect(await store.read(), isFalse);
      await store.write(true);
      expect(await store.read(), isTrue);
    });
  });
}
