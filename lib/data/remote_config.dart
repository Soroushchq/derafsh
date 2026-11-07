/// Best-effort remote config fetch at startup.
///
/// The owner-operated Worker (`Config.remoteConfigUrl`) can override the
/// Telegram bot URL and report the latest release. Every failure is silent —
/// the app must stay fully usable offline with the bundled catalog.
library;

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import '../core/config.dart';

class RemoteConfig {
  const RemoteConfig({this.botUrl, this.latestVersionName});

  final String? botUrl;
  final String? latestVersionName;
}

/// Applies the remote values into [Config]-backed mutable runtime state.
class RuntimeConfig {
  RuntimeConfig._();

  static String botUrl = Config.telegramBotUrl;

  /// Test seam: when set, [refresh] uses the client it returns instead of
  /// constructing its own (so tests can observe close()).
  @visibleForTesting
  static http.Client Function()? clientFactory;

  /// Called by main() right after catalog load; never throws.
  static Future<void> refresh() async {
    final client = clientFactory?.call() ?? http.Client();
    try {
      final resp = await client
          .get(
            Uri.parse(Config.remoteConfigUrl),
            headers: {'User-Agent': 'Derafsh/${Config.appVersion}'},
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode < 200 || resp.statusCode >= 300) return;
      final map = jsonDecode(utf8.decode(resp.bodyBytes));
      if (map is! Map<String, dynamic>) return;
      if (map['ok'] != true) return;
      final bot = map['bot_url'];
      if (bot is String && bot.startsWith('https://t.me/')) {
        botUrl = bot;
      }
      developer.log('remote config applied (bot_url)', name: 'drf.config');
    } catch (_) {
      // silent — offline or endpoint unavailable
    } finally {
      client.close();
    }
  }
}

RemoteConfig parseRemoteConfig(String raw) {
  final map = jsonDecode(raw) as Map<String, dynamic>;
  return RemoteConfig(
    botUrl: map['bot_url'] as String?,
    latestVersionName: map['latest_version_name'] as String?,
  );
}
