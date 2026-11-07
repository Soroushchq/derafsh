/// Builds a sing-box v1.14 config document around a single outbound.
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
  /// Returns the full config JSON string for the given node.
  static String build(DrfNode node) {
    final outbound = Map<String, dynamic>.from(node.outbound);
    outbound['tag'] = 'proxy';

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
        outbound,
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
