/// Abstraction over the VPN engine.
///
/// [LibboxVpnEngine] implements this on Android over the official sing-box
/// libbox bindings (GPLv3). [UnsupportedEngine] is used where the native
/// core cannot run yet (e.g. unsigned iOS builds).
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

  /// Brings the tunnel up with the given sing-box config JSON.
  /// Throws [EngineException] on failure.
  Future<void> start(String config);

  /// Tears the tunnel down.
  Future<void> stop();
}

/// Simulated engine for widget tests: succeeds after [connectDelay], can be
/// told to fail. The config argument is ignored.
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
  String get label => 'استاب نمایشی (تست)';

  @override
  Future<void> start(String config) async {
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

/// Engine placeholder for platforms where the native core cannot run
/// (unsigned iOS builds): always fails with a clear Persian message.
class UnsupportedEngine implements VpnEngine {
  UnsupportedEngine(this.reason);

  final String reason;

  @override
  String get label => 'فعال نیست — $reason';

  @override
  Future<void> start(String config) async {
    throw EngineException(reason);
  }

  @override
  Future<void> stop() async {}
}
