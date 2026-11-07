/// Android engine over the official sing-box libbox bindings.
///
/// Talks to the native side through two channels:
///  * MethodChannel `app.derafsh.drf/vpn`  — start / stop
///  * EventChannel `app.derafsh.drf/vpn/events` — state stream
///
/// The native side (Kotlin) hosts the sing-box `CommandServer` inside an
/// Android `VpnService`; see android/app/src/main/kotlin/.../vpn/.
library;

import 'dart:async';

import 'package:flutter/services.dart';

import 'vpn_engine.dart';

class LibboxVpnEngine implements VpnEngine {
  LibboxVpnEngine();

  static const MethodChannel _channel = MethodChannel('app.derafsh.drf/vpn');
  static const EventChannel _events = EventChannel('app.derafsh.drf/vpn/events');

  Stream<Map<Object?, Object?>>? _stateStream;
  StreamSubscription<dynamic>? _subscription;

  String _lastState = 'disconnected';
  String? _lastError;

  @override
  String get label => 'sing-box (libbox)';

  /// Latest state pushed by the native side.
  /// Values: connecting | connected | disconnected
  String get lastNativeState => _lastState;

  @override
  Future<void> start(String config) async {
    _lastError = null;
    // Start listening before launching the service so no event is missed.
    final connected = Completer<bool>();
    _subscription?.cancel();
    _subscription = stateStream.listen((event) {
      final state = '${event['state'] ?? ''}';
      final error = event['error'];
      if (error != null && '$error'.isNotEmpty) {
        _lastError = '$error';
      }
      if (state == 'connected' && !connected.isCompleted) {
        connected.complete(true);
      } else if (state == 'disconnected' &&
          _lastError != null &&
          !connected.isCompleted) {
        connected.complete(false);
      }
    });

    try {
      final ok = await _channel.invokeMethod<bool>('start', {'config': config});
      if (ok == false) {
        throw EngineException(_lastError ?? 'دسترسی VPN داده نشد.');
      }
    } on PlatformException catch (e) {
      await _subscription?.cancel();
      _subscription = null;
      throw EngineException(e.message ?? 'شروع موتور ناموفق بود.');
    }

    final timer = Timer(const Duration(seconds: 45), () {
      if (!connected.isCompleted) connected.complete(false);
    });
    final success = await connected.future;
    timer.cancel();
    await _subscription?.cancel();
    _subscription = null;
    if (!success) {
      throw EngineException(_lastError ?? 'اتصال ناموفق بود.');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>('stop');
    } on PlatformException catch (e) {
      throw EngineException(e.message ?? 'توقف موتور ناموفق بود.');
    }
  }

  /// Broadcast stream of native state maps.
  Stream<Map<Object?, Object?>> get stateStream {
    _stateStream ??= _events
        .receiveBroadcastStream()
        .map((event) => event is Map
            ? Map<Object?, Object?>.from(event)
            : <Object?, Object?>{'state': 'disconnected'})
        .map((event) {
      final state = '${event['state'] ?? ''}';
      if (state.isNotEmpty) _lastState = state;
      return event;
    });
    return _stateStream!;
  }
}
