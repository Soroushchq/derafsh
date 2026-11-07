/// Parser for proxy share links (vmess / vless / trojan / ss / hysteria2 / tuic)
/// and generator of sing-box v1.14 outbound objects.
///
/// Supported link forms:
///  * `vmess://<base64 json>`
///  * `vless://uuid@host:port?...#name`
///  * `trojan://password@host:port?...#name`
///  * `ss://<base64(method:pass)>@host:port#name` and `ss://<base64(all)>#name`
///  * `hysteria2://|hy2://auth@host:port?...#name`
///  * `tuic://uuid:password@host:port?...#name`
library;

import 'dart:convert';

class DrfNode {
  DrfNode({
    required this.type,
    required this.tag,
    required this.server,
    required this.port,
  });

  final String type;
  final String tag;
  final String server;
  final int port;

  /// sing-box outbound object (v1.14 schema).
  Map<String, dynamic> outbound = {};

  /// Preference rank for automatic node picking (higher = better).
  int get rank {
    final tls = outbound['tls'] as Map<String, dynamic>?;
    final reality = tls?['reality'] as Map<String, dynamic>?;
    if (reality?['enabled'] == true) return 3;
    if (tls?['enabled'] == true) return 2;
    return 1;
  }
}

class LinkParser {
  /// Extracts nodes from a subscription body (plain links or base64 blob).
  static List<DrfNode> parseSubscription(String body) {
    var text = body.trim();
    if (!text.contains('://')) {
      final decoded = _tryBase64(text);
      if (decoded != null && decoded.contains('://')) {
        text = decoded;
      }
    }
    final nodes = <DrfNode>[];
    for (final rawLine in text.split(RegExp(r'[\r\n]+'))) {
      final line = rawLine.trim();
      if (line.isEmpty || !line.contains('://')) continue;
      final node = parseLink(line);
      if (node != null) nodes.add(node);
    }
    return nodes;
  }

  static DrfNode? parseLink(String link) {
    try {
      final schemeEnd = link.indexOf('://');
      if (schemeEnd <= 0) return null;
      final scheme = link.substring(0, schemeEnd).toLowerCase();
      switch (scheme) {
        case 'vmess':
          return _parseVmess(link);
        case 'vless':
          return _parseVless(link);
        case 'trojan':
          return _parseTrojan(link);
        case 'ss':
          return _parseShadowsocks(link);
        case 'hysteria2':
        case 'hy2':
          return _parseHysteria2(link);
        case 'tuic':
          return _parseTuic(link);
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ vmess

  static DrfNode? _parseVmess(String link) {
    final payload = link.substring('vmess://'.length).trim();
    final decoded = _tryBase64(payload);
    if (decoded == null) return null;
    final json = jsonDecode(decoded);
    if (json is! Map) return null;
    final server = '${json['add'] ?? ''}';
    final port = int.tryParse('${json['port'] ?? ''}') ?? 0;
    if (server.isEmpty || port <= 0) return null;
    final uuid = '${json['id'] ?? ''}';
    if (uuid.isEmpty) return null;

    final node = DrfNode(
      type: 'vmess',
      tag: _cleanTag('${json['ps']}') ?? 'vmess',
      server: server,
      port: port,
    );
    final tlsEnabled = '${json['tls'] ?? ''}' == 'tls';
    final sni = '${json['sni'] ?? json['host'] ?? ''}';
    final alpnRaw = '${json['alpn'] ?? ''}';
    final alpn = alpnRaw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final scy = '${json['scy'] ?? ''}';
    final outbound = <String, dynamic>{
      'type': 'vmess',
      'tag': node.tag,
      'server': server,
      'server_port': port,
      'uuid': uuid,
      'security': scy.isNotEmpty ? scy : 'auto',
      'alter_id': int.tryParse('${json['aid'] ?? 0}') ?? 0,
    };
    if (tlsEnabled) {
      final tls = <String, dynamic>{'enabled': true};
      if (sni.isNotEmpty) tls['server_name'] = sni;
      if (alpn.isNotEmpty) tls['alpn'] = alpn;
      final fp = '${json['fp'] ?? ''}';
      if (fp.isNotEmpty) {
        tls['utls'] = {'enabled': true, 'fingerprint': fp};
      }
      outbound['tls'] = tls;
    }
    final transport = _buildTransport(
      net: '${json['net'] ?? ''}',
      type: '${json['type'] ?? ''}',
      host: '${json['host'] ?? ''}',
      path: '${json['path'] ?? ''}',
    );
    if (transport != null) outbound['transport'] = transport;
    node.outbound = outbound;
    return node;
  }

  // ------------------------------------------------------------------ vless

  static DrfNode? _parseVless(String link) {
    final uri = Uri.parse(link);
    final userInfo = uri.userInfo;
    final host = uri.host;
    final port = uri.port;
    if (userInfo.isEmpty || host.isEmpty || port <= 0) return null;
    final q = uri.queryParameters;

    final node = DrfNode(
      type: 'vless',
      tag: _cleanTag(uri.fragment) ?? 'vless',
      server: host,
      port: port,
    );
    final outbound = <String, dynamic>{
      'type': 'vless',
      'tag': node.tag,
      'server': host,
      'server_port': port,
      'uuid': userInfo,
    };
    final flow = q['flow'] ?? '';
    if (flow.isNotEmpty) outbound['flow'] = flow;

    final security = q['security'] ?? '';
    if (security == 'tls' || security == 'reality') {
      final tls = <String, dynamic>{'enabled': true};
      final sni = q['sni'] ?? '';
      if (sni.isNotEmpty) tls['server_name'] = sni;
      final fp = q['fp'] ?? '';
      if (fp.isNotEmpty) {
        tls['utls'] = {'enabled': true, 'fingerprint': fp};
      }
      final alpn = (q['alpn'] ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (alpn.isNotEmpty) tls['alpn'] = alpn;
      if (security == 'reality') {
        tls['reality'] = {
          'enabled': true,
          'public_key': q['pbk'] ?? '',
          'short_id': q['sid'] ?? '',
        };
      }
      if (q['insecure'] == '1' || q['allowInsecure'] == '1') {
        tls['insecure'] = true;
      }
      outbound['tls'] = tls;
    }
    final transport = _buildTransport(
      net: q['type'] ?? '',
      type: q['headerType'] ?? '',
      host: q['host'] ?? '',
      path: q['path'] ?? '',
      serviceName: q['serviceName'] ?? '',
    );
    if (transport != null) outbound['transport'] = transport;
    node.outbound = outbound;
    return node;
  }

  // ----------------------------------------------------------------- trojan

  static DrfNode? _parseTrojan(String link) {
    final uri = Uri.parse(link);
    final password = _decodeComponent(uri.userInfo);
    final host = uri.host;
    final port = uri.port;
    if (password.isEmpty || host.isEmpty || port <= 0) return null;
    final q = uri.queryParameters;

    final node = DrfNode(
      type: 'trojan',
      tag: _cleanTag(uri.fragment) ?? 'trojan',
      server: host,
      port: port,
    );
    final outbound = <String, dynamic>{
      'type': 'trojan',
      'tag': node.tag,
      'server': host,
      'server_port': port,
      'password': password,
    };
    final sni = q['sni'] ?? q['peer'] ?? '';
    final tls = <String, dynamic>{'enabled': true};
    if (sni.isNotEmpty) tls['server_name'] = sni;
    if (q['insecure'] == '1' || q['allowInsecure'] == '1') {
      tls['insecure'] = true;
    }
    final fp = q['fp'] ?? '';
    if (fp.isNotEmpty) {
      tls['utls'] = {'enabled': true, 'fingerprint': fp};
    }
    outbound['tls'] = tls;
    final transport = _buildTransport(
      net: q['type'] ?? '',
      type: q['headerType'] ?? '',
      host: q['host'] ?? '',
      path: q['path'] ?? '',
      serviceName: q['serviceName'] ?? '',
    );
    if (transport != null) outbound['transport'] = transport;
    node.outbound = outbound;
    return node;
  }

  // ------------------------------------------------------------ shadowsocks

  static DrfNode? _parseShadowsocks(String link) {
    final rest = link.substring('ss://'.length);
    final hashIdx = rest.indexOf('#');
    final fragment = hashIdx >= 0 ? rest.substring(hashIdx + 1) : '';
    final body = hashIdx >= 0 ? rest.substring(0, hashIdx) : rest;

    // SIP002: ss://base64(method:pass)@host:port
    final uri = Uri.tryParse(link);
    if (uri != null && uri.host.isNotEmpty && uri.port > 0 && uri.userInfo.isNotEmpty) {
      final decoded =
          _tryBase64(uri.userInfo) ?? _decodeComponent(uri.userInfo);
      final idx = decoded.indexOf(':');
      if (idx > 0) {
        return _buildSsNode(
          decoded.substring(0, idx),
          decoded.substring(idx + 1),
          uri.host,
          uri.port,
          fragment,
        );
      }
    }

    // legacy: ss://base64(method:pass@host:port)
    final decoded = _tryBase64(body) ?? '';
    final at = decoded.lastIndexOf('@');
    if (at <= 0) return null;
    var hostPort = decoded.substring(at + 1);
    final stop = RegExp(r'[/?]').firstMatch(hostPort);
    if (stop != null) hostPort = hostPort.substring(0, stop.start);
    final colon = hostPort.lastIndexOf(':');
    if (colon <= 0) return null;
    final host = hostPort.substring(0, colon);
    final port = int.tryParse(hostPort.substring(colon + 1)) ?? 0;
    if (host.isEmpty || port <= 0) return null;
    final head = decoded.substring(0, at);
    final idx = head.indexOf(':');
    if (idx <= 0) return null;
    return _buildSsNode(head.substring(0, idx), head.substring(idx + 1), host, port, fragment);
  }

  static DrfNode _buildSsNode(
    String method,
    String password,
    String host,
    int port,
    String fragment,
  ) {
    final node = DrfNode(
      type: 'shadowsocks',
      tag: _cleanTag(fragment) ?? 'ss',
      server: host,
      port: port,
    );
    node.outbound = {
      'type': 'shadowsocks',
      'tag': node.tag,
      'server': host,
      'server_port': port,
      'method': method,
      'password': password,
    };
    return node;
  }

  // -------------------------------------------------------------- hysteria2

  static DrfNode? _parseHysteria2(String link) {
    final uri = Uri.parse(link);
    final password = _decodeComponent(uri.userInfo);
    final host = uri.host;
    var port = uri.port;
    if (host.isEmpty) return null;
    if (port <= 0) port = 443;
    final q = uri.queryParameters;

    final node = DrfNode(
      type: 'hysteria2',
      tag: _cleanTag(uri.fragment) ?? 'hy2',
      server: host,
      port: port,
    );
    final tls = <String, dynamic>{'enabled': true};
    final sni = q['sni'] ?? '';
    if (sni.isNotEmpty) tls['server_name'] = sni;
    if (q['insecure'] == '1') tls['insecure'] = true;
    node.outbound = {
      'type': 'hysteria2',
      'tag': node.tag,
      'server': host,
      'server_port': port,
      'password': password,
      'tls': tls,
    };
    return node;
  }

  // ------------------------------------------------------------------- tuic

  static DrfNode? _parseTuic(String link) {
    final uri = Uri.parse(link);
    final userInfo = _decodeComponent(uri.userInfo);
    final idx = userInfo.indexOf(':');
    if (idx <= 0) return null;
    final uuid = userInfo.substring(0, idx);
    final password = userInfo.substring(idx + 1);
    final host = uri.host;
    final port = uri.port <= 0 ? 443 : uri.port;
    if (host.isEmpty || uuid.isEmpty) return null;
    final q = uri.queryParameters;

    final node = DrfNode(
      type: 'tuic',
      tag: _cleanTag(uri.fragment) ?? 'tuic',
      server: host,
      port: port,
    );
    final tls = <String, dynamic>{'enabled': true};
    final sni = q['sni'] ?? '';
    if (sni.isNotEmpty) tls['server_name'] = sni;
    final alpn = (q['alpn'] ?? 'h3')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (alpn.isNotEmpty) tls['alpn'] = alpn;
    if (q['insecure'] == '1') tls['insecure'] = true;
    node.outbound = {
      'type': 'tuic',
      'tag': node.tag,
      'server': host,
      'server_port': port,
      'uuid': uuid,
      if (password.isNotEmpty) 'password': password,
      'congestion_control': q['congestion_control'] ?? 'bbr',
      'tls': tls,
    };
    return node;
  }

  // ---------------------------------------------------------------- helpers

  /// Builds a sing-box transport object from link parameters, or null.
  static Map<String, dynamic>? _buildTransport({
    required String net,
    required String type,
    required String host,
    required String path,
    String serviceName = '',
  }) {
    switch (net) {
      case 'ws':
        final transport = <String, dynamic>{'type': 'ws'};
        if (path.isNotEmpty) transport['path'] = path;
        if (host.isNotEmpty) transport['headers'] = {'Host': host};
        final ed = RegExp(r'ed=(\d+)').firstMatch(path);
        if (ed != null) {
          transport['max_early_data'] = int.tryParse(ed.group(1)!) ?? 2048;
          transport['early_data_header_name'] = 'Sec-WebSocket-Protocol';
        }
        return transport;
      case 'grpc':
        final transport = <String, dynamic>{'type': 'grpc'};
        if (serviceName.isNotEmpty) transport['service_name'] = serviceName;
        return transport;
      case 'h2':
        final transport = <String, dynamic>{'type': 'http'};
        if (host.isNotEmpty) transport['host'] = host.split(',');
        if (path.isNotEmpty) transport['path'] = path;
        return transport;
      case 'httpupgrade':
        final transport = <String, dynamic>{'type': 'httpupgrade'};
        if (path.isNotEmpty) transport['path'] = path;
        if (host.isNotEmpty) transport['host'] = host;
        return transport;
      default:
        return null;
    }
  }

  static String _decodeComponent(String raw) {
    try {
      return Uri.decodeComponent(raw);
    } catch (_) {
      return raw;
    }
  }

  static String? _cleanTag(String raw) {
    String tag;
    try {
      tag = _decodeComponent(raw).trim();
    } catch (_) {
      // Uri.decodeComponent throws ArgumentError on non-percent-encoded text
      tag = raw.trim();
    }
    if (tag.isEmpty) return null;
    return tag.length > 48 ? tag.substring(0, 48) : tag;
  }

  static String? _tryBase64(String input) {
    final cleaned =
        input.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
    for (final candidate in [cleaned, _pad(cleaned), _padUrl(cleaned)]) {
      try {
        final bytes = base64.decode(candidate);
        final text = utf8.decode(bytes, allowMalformed: true);
        if (text.isNotEmpty) return text;
      } catch (_) {
        // try next candidate
      }
    }
    return null;
  }

  static String _pad(String s) {
    final mod = s.length % 4;
    return mod == 0 ? s : s + '=' * (4 - mod);
  }

  static String _padUrl(String s) =>
      _pad(s.replaceAll('-', '+').replaceAll('_', '/'));
}
