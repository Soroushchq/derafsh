/// Rolling 24h usage ledger for the free tier.
///
/// Persists {timestamp, seconds} buckets and computes how much free time
/// remains inside any rolling 24-hour window.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Storage seam so tests can run fully in-memory.
abstract class LedgerStore {
  Future<String?> read();

  Future<void> write(String raw);
}

class PrefsLedgerStore implements LedgerStore {
  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  @override
  Future<void> write(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, raw);
  }

  static const String _prefsKey = 'drf.usage.buckets.v1';
}

class MemoryLedgerStore implements LedgerStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String raw) async {
    _value = raw;
  }
}

class UsageLedger {
  UsageLedger({LedgerStore? store, this.window = const Duration(hours: 24)})
      : store = store ?? PrefsLedgerStore();

  final LedgerStore store;
  final Duration window;

  /// List of [timestampMillis, seconds] buckets.
  List<(int, int)> _buckets = [];

  bool _loaded = false;

  /// Total seconds already consumed within the trailing [window].
  int usedSeconds({DateTime? now}) {
    _prune(now: now);
    var total = 0;
    for (final (_, seconds) in _buckets) {
      total += seconds;
    }
    return total;
  }

  /// Records [seconds] of connected time, batched into coarse buckets.
  Future<void> addSeconds(int seconds, {DateTime? now}) async {
    if (seconds <= 0) return;
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
    if (_buckets.isNotEmpty && ts - _buckets.last.$1 < 60000) {
      // merge into the last bucket (same minute)
      final last = _buckets.removeLast();
      _buckets.add((last.$1, last.$2 + seconds));
    } else {
      _buckets.add((ts, seconds));
    }
    _prune(now: now);
    await _persist();
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final raw = await store.read();
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<List>();
        _buckets = list
            .map((e) => ((e[0] as num).toInt(), (e[1] as num).toInt()))
            .toList(growable: true);
      } catch (_) {
        _buckets = [];
      }
    }
    _loaded = true;
  }

  void _prune({DateTime? now}) {
    final cutoff =
        (now ?? DateTime.now()).subtract(window).millisecondsSinceEpoch;
    _buckets = _buckets.where((b) => b.$1 >= cutoff).toList();
  }

  Future<void> _persist() async {
    final raw = jsonEncode(
      _buckets.map((b) => [b.$1, b.$2]).toList(growable: false),
    );
    await store.write(raw);
  }
}
