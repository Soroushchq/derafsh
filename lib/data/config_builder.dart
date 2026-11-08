/// Builds a sing-box v1.14 config document around one outbound or a pool.
///
/// Notes on the schema (sing-box 1.14.x):
///  * tun inbound uses merged `address` (legacy inet4_address was removed in 1.12)
///  * sniffing happens via a route rule action, not `inbound.sniff` (removed 1.13)
///  * DNS servers use the new typed format (legacy formats removed in 1.14)
///  * no `block`/`dns` special outbounds (removed 1.13) — rule actions instead
library;

import 'dart:convert';

import 'link_parser.dart';

class ConfigBuilder {
  /// Probe URL for the urltest health checks. It is fetched THROUGH each
  /// member proxy, so reachability inside Iran is irrelevant; any 204
  /// endpoint on the open internet works.
  static const String probeUrl = 'https://www.gstatic.com/generate_204';

  /// How many ranked nodes take part in the health-checked pool. Every
  /// member is probed once per interval, so the cap keeps battery and
  /// mobile data in check while still covering the best candidates.
  static const int maxPoolMembers = 24;

  /// Returns the full config JSON string for the given node.
  static String build(DrfNode node) => _assemble([_tagged(node, 'proxy')]);

  /// Returns the full config JSON for a health-checked pool of nodes.
  ///
  /// sing-box probes every member through its real protocol and routes
  /// traffic via the alive member with the lowest latency, re-testing on
  /// `interval` — so dead or newly blocked configs are skipped without the
  /// app doing anything. `nodes` must be ordered best-first (caller owns
  /// ranking); only the first [maxMembers] join the pool.
  static String buildPool(List<DrfNode> nodes, {int maxMembers = maxPoolMembers}) {
    if (maxMembers < 1) {
      throw ArgumentError.value(maxMembers, 'maxMembers', 'must be >= 1');
    }
    if (nodes.isEmpty) {
      throw ArgumentError.value(nodes, 'nodes', 'must not be empty');
    }
    if (nodes.length == 1) return build(nodes.single);

    final members = nodes.take(maxMembers).toList();
    final tagged = <Map<String, dynamic>>[
      {
        'type': 'urltest',
        'tag': 'proxy',
        'outbounds': [
          for (var i = 0; i < members.length; i++) 'n${i + 1}',
        ],
        'url': probeUrl,
        'interval': '3m',
        'tolerance': 50,
      },
      for (var i = 0; i < members.length; i++) _tagged(members[i], 'n${i + 1}'),
    ];
    return _assemble(tagged);
  }

  static Map<String, dynamic> _tagged(DrfNode node, String tag) {
    final outbound = Map<String, dynamic>.from(node.outbound);
    outbound['tag'] = tag;
    return outbound;
  }

  static String _assemble(List<Map<String, dynamic>> outbounds) {
    final config = <String, dynamic>{
      'log': {'level': 'warn', 'timestamp': true},
      'dns': {
        'servers': [
          {
            'type': 'https',
            'tag': 'dns-proxy',
            'server': '1.1.1.1',
            'detour': 'proxy',
          },
          {'type': 'local', 'tag': 'dns-direct'},
        ],
        'final': 'dns-proxy',
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
          'mtu': 9000,
          'auto_route': true,
          'strict_route': true,
          'stack': 'mixed',
        },
      ],
      'outbounds': [
        ...outbounds,
        {'type': 'direct', 'tag': 'direct'},
      ],
      'route': {
        'rules': [
          {'action': 'sniff'},
          {'protocol': 'dns', 'action': 'hijack-dns'},
          {'ip_is_private': true, 'outbound': 'direct'},
        ],
        'final': 'proxy',
        'auto_detect_interface': true,
        'default_domain_resolver': {'server': 'dns-direct'},
      },
    };

    return jsonEncode(config);
  }
}
