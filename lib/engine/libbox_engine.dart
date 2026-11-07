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
  LibboxVpnEngine() {
    // Permanent observer (B2 fix): native state changes must be recorded for
    // the whole app lifetime, not only while start() is waiting — otherwise a
    // tunnel that dies mid-session is never reported upward.
    events.listen(_record);
  }

  static const MethodChannel _channel = MethodChannel('app.derafsh.drf/vpn');
  static const EventChannel _events = EventChannel('app.derafsh.drf/vpn/events');

  Stream<Map<Object?, Object?>>? _broadcast;

  String _lastState = 'disconnected';
  String? _lastError;

  @override
  String get label => 'sing-box (libbox)';

  /// Latest state pushed by the native side.
  /// Values: connecting | connected | disconnected
  String get lastNativeState => _lastState;

  /// Latest native error text, if any.
  String? get lastError => _lastError;

  void _record(Map<Object?, Object?> event) {
    final state = '${event['state'] ?? ''}';
    if (state.isNotEmpty) _lastState = state;
    final error = event['error'];
    if (error != null && '$error'.isNotEmpty) _lastError = '$error';
  }

  /// Broadcast stream of native state maps (single cached instance).
  Stream<Map<Object?, Object?>> get events {
    _broadcast ??= _events
        .receiveBroadcastStream()
        .map((event) => event is Map
            ? Map<Object?, Object?>.from(event)
            : <Object?, Object?>{'state': 'disconnected'});
    return _broadcast!;
  }

  @override
  Stream<Map<Object?, Object?>>? get stateEvents => events;

  @override
  Future<void> start(String config) async {
    _lastError = null;
    // Wait for the native "connected" (or failure) event. The permanent
    // constructor listener keeps recording; this temp listener completes the
    // start handshake.
    final connected = Completer<bool>();
    final sub = events.listen((event) {
      final state = '${event['state'] ?? ''}';
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
      await sub.cancel();
      throw EngineException(e.message ?? 'شروع موتور ناموفق بود.');
    }

    final timer = Timer(const Duration(seconds: 45), () {
      if (!connected.isCompleted) connected.complete(false);
    });
    final success = await connected.future;
    timer.cancel();
    await sub.cancel();
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
}
