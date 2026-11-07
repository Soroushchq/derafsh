import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/vpn_engine.dart';

enum VpnPhase { disconnected, connecting, connected, disconnecting }

/// Owns connection state, the session timer and the free-tier quota.
///
/// PART 1 notes:
/// - quota is session-local; the per-device rolling 24h window becomes
///   authoritative on the Worker in PART 3.
/// - [premium] is a stub until license activation lands (PART 3/4).
class VpnController extends ChangeNotifier {
  VpnController({
    required this.engine,
    this.freeDailyLimit = const Duration(minutes: 30),
    bool premium = false,
  })  : _premium = premium,
        freeRemaining = freeDailyLimit;

  final VpnEngine engine;
  final Duration freeDailyLimit;

  VpnPhase _phase = VpnPhase.disconnected;
  bool _premium;
  bool _timedOutLastSession = false;
  int _selectedSource = 0;
  Duration _elapsed = Duration.zero;
  Duration freeRemaining;
  bool hasError = false;

  Timer? _ticker;

  VpnPhase get phase => _phase;
  bool get premium => _premium;
  bool get timedOutLastSession => _timedOutLastSession;
  int get selectedSource => _selectedSource;
  Duration get elapsed => _elapsed;

  bool get isBusy =>
      _phase == VpnPhase.connecting || _phase == VpnPhase.disconnecting;

  /// Marks the premium flag (activation flow in PART 3/4).
  set premium(bool value) {
    if (_premium == value) return;
    _premium = value;
    notifyListeners();
  }

  void selectSource(int index) {
    if (index == _selectedSource) return;
    _selectedSource = index;
    notifyListeners();
  }

  Future<void> connect() async {
    if (isBusy || _phase == VpnPhase.connected) return;
    hasError = false;
    _timedOutLastSession = false;
    _setPhase(VpnPhase.connecting);
    try {
      await engine.start();
      _elapsed = Duration.zero;
      _setPhase(VpnPhase.connected);
      _startTicker();
    } on EngineException {
      hasError = true;
      _setPhase(VpnPhase.disconnected);
    }
  }

  Future<void> disconnect({bool timedOut = false}) async {
    if (_phase != VpnPhase.connected && _phase != VpnPhase.connecting) return;
    _stopTicker();
    _setPhase(VpnPhase.disconnecting);
    try {
      await engine.stop();
    } finally {
      _timedOutLastSession = timedOut;
      _setPhase(VpnPhase.disconnected);
    }
  }

  /// Consumes the timeout flag so a dialog is only shown once.
  bool consumeTimeoutFlag() {
    final v = _timedOutLastSession;
    _timedOutLastSession = false;
    return v;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    _elapsed += const Duration(seconds: 1);
    if (!_premium) {
      if (freeRemaining > Duration.zero) {
        freeRemaining -= const Duration(seconds: 1);
      }
      if (freeRemaining <= Duration.zero) {
        freeRemaining = Duration.zero;
        unawaited(disconnect(timedOut: true));
        return;
      }
    }
    notifyListeners();
  }

  void _setPhase(VpnPhase p) {
    _phase = p;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}
