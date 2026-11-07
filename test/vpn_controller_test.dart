import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drf/engine/vpn_engine.dart';
import 'package:drf/state/vpn_controller.dart';
import 'package:drf/ui/update_gate.dart';

void main() {
  test('connect succeeds and ticks elapsed time', () {
    fakeAsync((async) {
      final c = VpnController(
        engine: StubVpnEngine(
          connectDelay: const Duration(milliseconds: 10),
          stopDelay: const Duration(milliseconds: 5),
        ),
        freeDailyLimit: const Duration(minutes: 30),
      );
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
      final c = VpnController(
        engine: StubVpnEngine(
          connectDelay: const Duration(milliseconds: 10),
          stopDelay: const Duration(milliseconds: 5),
        ),
        freeDailyLimit: const Duration(seconds: 5),
      );
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
      final c = VpnController(
        engine: StubVpnEngine(
          connectDelay: const Duration(milliseconds: 10),
          stopDelay: const Duration(milliseconds: 5),
        ),
        freeDailyLimit: const Duration(seconds: 5),
        premium: true,
      );
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
      final engine = StubVpnEngine(
        connectDelay: const Duration(milliseconds: 10),
        failConnect: true,
      );
      final c = VpnController(engine: engine);
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
