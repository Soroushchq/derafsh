/// Abstraction over the VPN engine.
///
/// PART 1 ships with [StubVpnEngine] so the whole UI is exercisable without
/// the native core. In PART 2 this interface is implemented on top of the
/// official sing-box libbox bindings (GPLv3).
library;

class EngineException implements Exception {
  EngineException(this.message);
  final String message;

  @override
  String toString() => 'EngineException: $message';
}

abstract class VpnEngine {
  /// Short human-readable label (shown in the hidden Advanced sheet).
  String get label;

  /// Brings the tunnel up. Throws [EngineException] on failure.
  Future<void> start();

  /// Tears the tunnel down.
  Future<void> stop();
}

/// Simulated engine: succeeds after [connectDelay], can be told to fail.
class StubVpnEngine implements VpnEngine {
  StubVpnEngine({
    this.connectDelay = const Duration(milliseconds: 2200),
    this.stopDelay = const Duration(milliseconds: 400),
    this.failConnect = false,
  });

  final Duration connectDelay;
  final Duration stopDelay;
  bool failConnect;

  @override
  String get label => 'استاب نمایشی (نسخهٔ بعدی: sing-box)';

  @override
  Future<void> start() async {
    await Future<void>.delayed(connectDelay);
    if (failConnect) {
      throw EngineException('simulated failure');
    }
  }

  @override
  Future<void> stop() async {
    await Future<void>.delayed(stopDelay);
  }
}
