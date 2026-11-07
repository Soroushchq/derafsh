import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/drf_source.dart';
import '../data/node_resolver.dart';
import '../data/usage_ledger.dart';
import '../engine/vpn_engine.dart';

enum VpnPhase { disconnected, connecting, connected, disconnecting }

/// Owns connection state, the session timer and the free-tier quota.
///
/// - the quota is a rolling 24h window per device, persisted locally
///   ([UsageLedger]); the Worker becomes authoritative once deployed.
/// - [premium] unlocks every source and removes the quota.
class VpnController extends ChangeNotifier {
  VpnController({
    required this.engine,
    required this.catalog,
    required this.nodeResolver,
    this.freeLimit = const Duration(minutes: 30),
    bool premium = false,
    UsageLedger? ledger,
  })  : _premium = premium,
        ledger = ledger ?? UsageLedger(),
        freeRemaining = freeLimit;

  final VpnEngine engine;
  final SourceCatalog catalog;
  final NodeResolver nodeResolver;
  final Duration freeLimit;
  final UsageLedger ledger;

  VpnPhase _phase = VpnPhase.disconnected;
  bool _premium;
  bool _timedOutLastSession = false;
  int _selectedSource = 0;
  Duration _elapsed = Duration.zero;
  Duration freeRemaining;
  bool hasError = false;
  String? lastErrorMessage;
  String activeSourceName = '';

  Timer? _ticker;
  int _unsavedSeconds = 0;
  bool _ledgerReady = false;

  VpnPhase get phase => _phase;
  bool get premium => _premium;
  bool get timedOutLastSession => _timedOutLastSession;
  int get selectedSource => _selectedSource;
  Duration get elapsed => _elapsed;

  bool get isBusy =>
      _phase == VpnPhase.connecting || _phase == VpnPhase.disconnecting;

  /// Marks the premium flag (activation flow arrives with the Worker/bot).
  set premium(bool value) {
    if (_premium == value) return;
    _premium = value;
    if (_premium) freeRemaining = freeLimit;
    notifyListeners();
  }

  void selectSource(int index) {
    if (index == _selectedSource) return;
    _selectedSource = index;
    notifyListeners();
  }

  /// The source this controller would connect to right now.
  DrfSource get effectiveSource =>
      catalog.effectiveSource(_selectedSource, _premium);

  Future<void> connect() async {
    if (isBusy || _phase == VpnPhase.connected) return;
    if (!_premium && freeRemaining <= Duration.zero) {
      _timedOutLastSession = true;
      notifyListeners();
      return;
    }
    hasError = false;
    lastErrorMessage = null;
    _timedOutLastSession = false;
    _setPhase(VpnPhase.connecting);
    try {
      if (catalog.isEmpty) {
        throw EngineException('هیچ سورسی موجود نیست.');
      }
      if (!_ledgerReady) {
        await ledger.ensureLoaded();
        _syncFreeRemaining();
        _ledgerReady = true;
        if (!_premium && freeRemaining <= Duration.zero) {
          _setPhase(VpnPhase.disconnected);
          _timedOutLastSession = true;
          notifyListeners();
          return;
        }
      }
      final source = effectiveSource;
      // failover: if the primary source is dead, try the following ones
      final fallbackUrls = <String>[];
      for (final s in catalog.sources) {
        if (s.url != source.url &&
            !fallbackUrls.contains(s.url) &&
            fallbackUrls.length < 5) {
          fallbackUrls.add(s.url);
        }
      }
      final resolved = await nodeResolver.resolve(
        source.url,
        fallbackUrls: fallbackUrls,
      );
      final used = catalog.sources.firstWhere(
        (s) => s.url == resolved.sourceUrl,
        orElse: () => source,
      );
      activeSourceName = used.name;
      await engine.start(resolved.config);
      _elapsed = Duration.zero;
      _setPhase(VpnPhase.connected);
      _startTicker();
    } on EngineException catch (e) {
      hasError = true;
      lastErrorMessage = e.message;
      _setPhase(VpnPhase.disconnected);
    } catch (_) {
      hasError = true;
      lastErrorMessage = null;
      _setPhase(VpnPhase.disconnected);
    }
  }

  Future<void> disconnect({bool timedOut = false}) async {
    if (_phase != VpnPhase.connected && _phase != VpnPhase.connecting) return;
    _stopTicker();
    _setPhase(VpnPhase.disconnecting);
    try {
      await engine.stop();
    } on EngineException {
      // engine already down — treat as disconnected
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
      _unsavedSeconds += 1;
      if (freeRemaining > Duration.zero) {
        freeRemaining -= const Duration(seconds: 1);
      }
      if (freeRemaining <= Duration.zero) {
        freeRemaining = Duration.zero;
        // flush the ledger, then cut the tunnel
        unawaited(
          ledger
              .addSeconds(_unsavedSeconds)
              .then((_) => _unsavedSeconds = 0),
        );
        unawaited(disconnect(timedOut: true));
        return;
      }
      if (_unsavedSeconds >= 5) {
        final batch = _unsavedSeconds;
        _unsavedSeconds = 0;
        unawaited(ledger.addSeconds(batch).then((_) => _syncFreeRemaining()));
      }
    }
    notifyListeners();
  }

  void _syncFreeRemaining() {
    final used = ledger.usedSeconds();
    final remainingSeconds = freeLimit.inSeconds - used;
    freeRemaining = Duration(
      seconds: remainingSeconds.clamp(0, freeLimit.inSeconds),
    );
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
