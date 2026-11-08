import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/admin_store.dart';
import '../data/drf_source.dart';
import '../data/node_resolver.dart';
import '../data/usage_ledger.dart';
import '../engine/vpn_engine.dart';

enum VpnPhase { disconnected, connecting, connected, disconnecting }

/// Owns connection state, the session timer and the free-tier quota.
///
/// - the quota is a rolling 24h window per device, persisted locally
///   ([UsageLedger]); the Worker becomes authoritative once deployed.
/// - [premium] and [admin] unlock every source and remove the quota
///   ([admin] is the owner shortcut, persisted via [AdminStore]).
class VpnController extends ChangeNotifier {
  VpnController({
    required this.engine,
    required this.catalog,
    required this.nodeResolver,
    this.freeLimit = const Duration(minutes: 30),
    bool premium = false,
    UsageLedger? ledger,
    AdminStore? adminStore,
  })  : _premium = premium,
        adminStore = adminStore ?? MemoryAdminStore(),
        ledger = ledger ?? UsageLedger(),
        freeRemaining = freeLimit {
    // B6 fix: load the persisted rolling-window usage immediately so the
    // usage strip and the connect gate reflect reality from app start.
    unawaited(_initLedger());
    // restore the persisted admin flag (owner code) right after start.
    _adminInit = _initAdmin();
    unawaited(_adminInit);
    // B2 fix: keep listening to native state for the whole app lifetime so a
    // tunnel that dies mid-session is reflected in the UI and the quota.
    final events = engine.stateEvents;
    if (events != null) {
      _engineEventsSub = events.listen(_onNativeState);
    }
  }

  final VpnEngine engine;
  final SourceCatalog catalog;
  final NodeResolver nodeResolver;
  final Duration freeLimit;
  final UsageLedger ledger;
  final AdminStore adminStore;

  VpnPhase _phase = VpnPhase.disconnected;
  bool _premium;
  bool _admin = false;
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
  Future<void>? _adminInit;
  StreamSubscription<Map<Object?, Object?>>? _engineEventsSub;

  VpnPhase get phase => _phase;
  bool get premium => _premium;

  /// Owner/admin shortcut — implies every [premium] entitlement.
  bool get admin => _admin;

  /// Whether every source and unlimited time are available right now.
  bool get unlocked => _premium || _admin;
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
    _safeNotify();
  }

  /// Marks admin mode (owner code gate in the UI) and persists it.
  Future<void> setAdmin(bool value) async {
    if (_admin == value) return;
    _admin = value;
    if (_admin) freeRemaining = freeLimit;
    try {
      await adminStore.write(value);
    } catch (_) {
      // persistence is best-effort; the in-memory flag stays authoritative
    }
    _safeNotify();
  }

  void selectSource(int index) {
    if (index == _selectedSource) return;
    _selectedSource = index;
    _safeNotify();
  }

  /// The source this controller would connect to right now
  /// (null when the catalog is empty — connect is not possible).
  DrfSource? get effectiveSource =>
      catalog.effectiveSource(_selectedSource, unlocked);

  Future<void> connect() async {
    if (isBusy || _phase == VpnPhase.connected) return;
    if (!unlocked && freeRemaining <= Duration.zero) {
      _timedOutLastSession = true;
      _safeNotify();
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
        if (!unlocked && freeRemaining <= Duration.zero) {
          _setPhase(VpnPhase.disconnected);
          _timedOutLastSession = true;
          _safeNotify();
          return;
        }
      }
      final source = effectiveSource;
      if (source == null) {
        // Unreachable when catalog is non-empty (guarded above); kept as a
        // defensive check so an empty catalog can never crash the app.
        throw EngineException('هیچ سورسی موجود نیست.');
      }
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
    // B1 fix: flush whatever the 5-second batching had not saved yet.
    await _flushPending();
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

  /// Writes the pending (0–4s) usage batch into the ledger.
  Future<void> _flushPending() async {
    final batch = _unsavedSeconds;
    if (batch <= 0) return;
    _unsavedSeconds = 0;
    await ledger.addSeconds(batch);
    _syncFreeRemaining();
  }

  /// Handles native state events for the whole app lifetime.
  void _onNativeState(Map<Object?, Object?> event) {
    final state = '${event['state'] ?? ''}';
    final error = event['error'];
    final errMsg = (error == null || '$error'.isEmpty) ? null : '$error';
    if (state != 'disconnected') return;
    if (_phase == VpnPhase.connected) {
      // Unexpected native drop: the tunnel died without the user asking.
      _stopTicker();
      unawaited(_flushPending());
      hasError = true;
      lastErrorMessage = errMsg ?? 'اتصال قطع شد.';
      _setPhase(VpnPhase.disconnected);
    } else if (_phase == VpnPhase.connecting) {
      // start() observes the same event and will fail with the message.
      hasError = true;
      lastErrorMessage = errMsg;
    }
  }

  /// Loads persisted usage and syncs the visible remaining time.
  Future<void> _initLedger() async {
    await ledger.ensureLoaded();
    _syncFreeRemaining();
    _ledgerReady = true;
    _safeNotify();
  }

  /// Restores the persisted admin flag (owner code), never throws.
  Future<void> _initAdmin() async {
    try {
      _admin = await adminStore.read();
    } catch (_) {
      _admin = false;
    }
    if (_admin) freeRemaining = freeLimit;
    _safeNotify();
  }

  /// Test hook: resolves once the persisted admin flag has been applied.
  @visibleForTesting
  Future<void> debugWaitAdminInit() async => _adminInit;

  /// notifyListeners that tolerates a controller disposed mid-flight.
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Test hook: runs exactly one session tick (production uses Timer.periodic).
  @visibleForTesting
  void debugTick() => _tick();

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
    if (!unlocked) {
      _unsavedSeconds += 1;
      if (freeRemaining > Duration.zero) {
        freeRemaining -= const Duration(seconds: 1);
      }
      if (freeRemaining <= Duration.zero) {
        freeRemaining = Duration.zero;
        // flush the ledger, then cut the tunnel
        unawaited(_flushPending());
        unawaited(disconnect(timedOut: true));
        return;
      }
      if (_unsavedSeconds >= 5) {
        unawaited(_flushPending());
      }
    }
    _safeNotify();
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
    _safeNotify();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _stopTicker();
    unawaited(_engineEventsSub?.cancel());
    super.dispose();
  }
}
