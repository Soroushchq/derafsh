/// Admin access store + code gate.
///
/// Admin mode is the owner shortcut: it unlocks every catalog source and
/// removes the free-tier quota (same as premium), without touching the
/// paywall flow. The admin code itself never lives in the repository —
/// only its SHA-256 hash ([Config.adminCodeSha256] in core/config.dart).
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage seam so tests can run fully in-memory.
abstract class AdminStore {
  Future<bool> read();

  Future<void> write(bool value);
}

class PrefsAdminStore implements AdminStore {
  static const String _prefsKey = 'drf.admin.v1';

  @override
  Future<bool> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  @override
  Future<void> write(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}

class MemoryAdminStore implements AdminStore {
  bool _value = false;

  @override
  Future<bool> read() async => _value;

  @override
  Future<void> write(bool value) async {
    _value = value;
  }
}

/// True when the trimmed input hashes to [expectedSha256].
///
/// Comparison runs in constant-time-ish fashion over the hex digests
/// (string equality); the code itself is never persisted or logged.
bool adminCodeMatches(String input, String expectedSha256) {
  final digest = sha256.convert(utf8.encode(input.trim()));
  return digest.toString() == expectedSha256;
}
