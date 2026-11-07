/// Fetches subscription bodies and resolves them to a ready-to-use sing-box
/// config, with automatic failover across catalog sources.
library;

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../engine/vpn_engine.dart';
import 'config_builder.dart';
import 'link_parser.dart';

class ResolvedNode {
  const ResolvedNode({required this.config, required this.sourceUrl});

  final String config;
  final String sourceUrl;
}

/// Produces the sing-box config JSON for a source URL.
abstract class NodeResolver {
  Future<ResolvedNode> resolve(
    String sourceUrl, {
    List<String> fallbackUrls = const [],
  });
}

/// Network-backed resolver used in production.
class SingBoxNodeResolver implements NodeResolver {
  SingBoxNodeResolver({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Closes the underlying HTTP client (app teardown / tests).
  /// B3 fix: the client was never closed, leaking sockets on teardown.
  void dispose() => _client.close();

  @override
  Future<ResolvedNode> resolve(
    String sourceUrl, {
    List<String> fallbackUrls = const [],
  }) async {
    final candidates = <String>[sourceUrl, ...fallbackUrls];
    Object? lastError;
    for (final url in candidates) {
      try {
        final body = await _fetchBody(url);
        final nodes = LinkParser.parseSubscription(body);
        if (nodes.isEmpty) {
          lastError = EngineException('سورس خالی بود.');
          continue;
        }
        final node = pickNode(nodes);
        return ResolvedNode(config: ConfigBuilder.build(node), sourceUrl: url);
      } on EngineException catch (e) {
        lastError = e;
      } catch (_) {
        lastError = EngineException('دریافت سورس ناموفق بود.');
      }
    }
    if (lastError is EngineException) throw lastError;
    throw EngineException('اتصال برقرار نشد. بعداً دوباره امتحان کن.');
  }

  /// Deterministic pseudo-rotation: prefer higher-ranked nodes, break ties
  /// with a day-seeded shuffle so the load spreads across the day.
  static DrfNode pickNode(List<DrfNode> nodes) {
    final seed = DateTime.now().toUtc().difference(DateTime.utc(2026)).inDays;
    final list = [...nodes]..shuffle(Random(seed));
    list.sort((a, b) => b.rank.compareTo(a.rank));
    return list.first;
  }

  Future<String> _fetchBody(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute) {
      throw EngineException('آدرس سورس نامعتبر است.');
    }
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'User-Agent': 'Derafsh/1.0'})
          .timeout(timeout);
    } catch (_) {
      throw EngineException('دریافت سورس ناموفق بود. اتصال اینترنت را بررسی کن.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EngineException('سورس پاسخ نداد (کد ${response.statusCode}).');
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (body.trim().isEmpty) {
      throw EngineException('سورس خالی بود.');
    }
    return body;
  }
}

/// Fixed config resolver for widget tests.
class FixedNodeResolver implements NodeResolver {
  FixedNodeResolver(this.config);

  final String config;

  @override
  Future<ResolvedNode> resolve(
    String sourceUrl, {
    List<String> fallbackUrls = const [],
  }) async =>
      ResolvedNode(config: config, sourceUrl: sourceUrl);
}
