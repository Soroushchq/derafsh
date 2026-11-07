/// Best-effort remote config fetch at startup.
///
/// The owner-operated Worker (`Config.remoteConfigUrl`) can override the
/// Telegram bot URL and report the latest release. Every failure is silent —
/// the app must stay fully usable offline with the bundled catalog.
library;

import 'dart:convert';
import 'dart:developer' as developer;

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

  /// Called by main() right after catalog load; never throws.
  static Future<void> refresh() async {
    try {
      final resp = await http.Client()
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
