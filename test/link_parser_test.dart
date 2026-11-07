import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:drf/data/config_builder.dart';
import 'package:drf/data/link_parser.dart';

void main() {
  group('LinkParser · vmess', () {
    test('parses base64 json vmess link with ws+tls', () {
      final json = jsonEncode({
        'v': '2',
        'ps': 'تست سرور',
        'add': 'example.com',
        'port': '443',
        'id': 'b831381d-6324-4d53-ad4f-8cda48b30811',
        'aid': '0',
        'scy': 'auto',
        'net': 'ws',
        'host': 'cdn.example.com',
        'path': '/ws?ed=2048',
        'tls': 'tls',
        'sni': 'example.com',
        'fp': 'chrome',
      });
      final link = 'vmess://${base64.encode(utf8.encode(json))}';
      final node = LinkParser.parseLink(link);
      expect(node, isNotNull);
      expect(node!.type, 'vmess');
      expect(node.tag, 'تست سرور');
      final o = node.outbound;
      expect(o['server'], 'example.com');
      expect(o['server_port'], 443);
      expect(o['uuid'], 'b831381d-6324-4d53-ad4f-8cda48b30811');
      expect(o['security'], 'auto');
      expect(o['tls']['enabled'], isTrue);
      expect(o['tls']['server_name'], 'example.com');
      expect(o['tls']['utls']['fingerprint'], 'chrome');
      expect(o['transport']['type'], 'ws');
      expect(o['transport']['headers']['Host'], 'cdn.example.com');
      expect(o['transport']['max_early_data'], 2048);
    });

    test('rejects garbage', () {
      expect(LinkParser.parseLink('vmess://not-base64!!!'), isNull);
      expect(LinkParser.parseLink(''), isNull);
    });
  });

  group('LinkParser · vless', () {
    test('parses reality vision link', () {
      final link =
          'vless://b831381d-6324-4d53-ad4f-8cda48b30811@1.2.3.4:443'
          '?encryption=none&security=reality&sni=www.microsoft.com'
          '&fp=chrome&pbk=SbVKOEMjK0sIlbwg4akyBg5mL5KZwwB-ed4eEE7YnRc'
          '&sid=6ba85179&type=tcp&flow=xtls-rprx-vision#Reality%20Node';
      final node = LinkParser.parseLink(link);
      expect(node, isNotNull);
      expect(node!.type, 'vless');
      expect(node.tag, 'Reality Node');
      final o = node.outbound;
      expect(o['server'], '1.2.3.4');
      expect(o['server_port'], 443);
      expect(o['flow'], 'xtls-rprx-vision');
      expect(o['tls']['reality']['enabled'], isTrue);
      expect(o['tls']['reality']['public_key'], contains('SbVK'));
      expect(o['tls']['reality']['short_id'], '6ba85179');
      expect(o['tls']['utls']['fingerprint'], 'chrome');
      expect(o.containsKey('transport'), isFalse);
      expect(node.rank, 3);
    });

    test('parses ws link', () {
      final link =
          'vless://uuid-0000@host.example:2053?security=tls&sni=host.example'
          '&type=ws&host=host.example&path=%2Fpath#ws%20node';
      final node = LinkParser.parseLink(link);
      expect(node, isNotNull);
      final o = node!.outbound;
      expect(o['transport']['type'], 'ws');
      expect(o['transport']['path'], '/path');
    });
  });

  group('LinkParser · trojan', () {
    test('parses trojan link', () {
      final link =
          'trojan://pass%40word@5.6.7.8:443?sni=t.example&type=tcp#T';
      final node = LinkParser.parseLink(link);
      expect(node, isNotNull);
      final o = node!.outbound;
      expect(o['type'], 'trojan');
      expect(o['password'], 'pass@word');
      expect(o['tls']['server_name'], 't.example');
    });
  });

  group('LinkParser · shadowsocks', () {
    test('parses SIP002 link', () {
      final userinfo = base64.encode(utf8.encode('aes-256-gcm:secretpass'));
      final link = 'ss://$userinfo@9.9.9.9:8388#SS%20Node';
      final node = LinkParser.parseLink(link);
      expect(node, isNotNull);
      final o = node!.outbound;
      expect(o['type'], 'shadowsocks');
      expect(o['method'], 'aes-256-gcm');
      expect(o['password'], 'secretpass');
      expect(o['server_port'], 8388);
    });

    test('parses legacy fully-base64 link', () {
      final body = base64.encode(utf8.encode('chacha20-ietf-poly1305:pw@7.7.7.7:9999'));
      final node = LinkParser.parseLink('ss://$body');
      expect(node, isNotNull);
      final o = node!.outbound;
      expect(o['method'], 'chacha20-ietf-poly1305');
      expect(o['server'], '7.7.7.7');
    });
  });

  group('LinkParser · audit cycle 2', () {
    test('C1: vmess grpc takes service name from path', () {
      final json = jsonEncode({
        'v': '2',
        'ps': 'grpcNode',
        'add': 'g.example.com',
        'port': 443, // numeric port (int) in JSON — must parse too
        'id': 'b831381d-6324-4d53-ad4f-8cda48b30811',
        'aid': 0,
        'net': 'grpc',
        'path': 'grpcServiceName',
        'tls': 'tls',
        'sni': 'g.example.com',
      });
      final link = 'vmess://${base64.encode(utf8.encode(json))}';
      final node = LinkParser.parseLink(link);
      expect(node, isNotNull);
      final transport = node!.outbound['transport'] as Map<String, dynamic>;
      expect(transport['type'], 'grpc');
      expect(transport['service_name'], 'grpcServiceName');
    });

    test('C2: ss SIP002 plugin obfs-local maps to sing-box plugin fields',
        () {
      final userinfo = base64.encode(utf8.encode('aes-256-gcm:pw'));
      final link = 'ss://$userinfo@4.4.4.4:8388'
          '?plugin=obfs-local%3Bobfs%3Dhttp%3Bobfs-host%3Dcdn.example.com'
          '#obfsNode';
      final node = LinkParser.parseLink(link);
      expect(node, isNotNull);
      final o = node!.outbound;
      expect(o['plugin'], 'obfs-local');
      expect(o['plugin_opts'], contains('obfs-host=cdn.example.com'));
    });

    test('C2: unknown ss plugin is dropped, node still parses', () {
      final userinfo = base64.encode(utf8.encode('aes-256-gcm:pw'));
      final link = 'ss://$userinfo@4.4.4.4:8388?plugin=shadowtls#x';
      final node = LinkParser.parseLink(link);
      expect(node, isNotNull);
      expect(node!.outbound.containsKey('plugin'), isFalse);
    });
  });

  group('LinkParser · hysteria2', () {
    test('parses hy2 link', () {
      final node = LinkParser.parseLink(
          'hysteria2://letmein@10.0.0.1:36712?sni=hy.example&insecure=1#HY2');
      expect(node, isNotNull);
      final o = node!.outbound;
      expect(o['type'], 'hysteria2');
      expect(o['password'], 'letmein');
      expect(o['tls']['insecure'], isTrue);
    });
  });

  group('LinkParser · subscription body', () {
    test('decodes base64 body and skips unknown schemes', () {
      final body = [
        'vless://u@1.1.1.1:443?security=tls&type=tcp#a',
        'socks://ignored',
        'trojan://pw@2.2.2.2:443#b',
        'not a link',
      ].join('\n');
      final encoded = base64.encode(utf8.encode(body));
      final nodes = LinkParser.parseSubscription(encoded);
      expect(nodes.length, 2);
      expect(nodes[0].type, 'vless');
      expect(nodes[1].type, 'trojan');
    });

    test('accepts plain body', () {
      final nodes = LinkParser.parseSubscription(
        'ss://${base64.encode(utf8.encode('aes-128-gcm:x'))}@3.3.3.3:80#s\n',
      );
      expect(nodes.length, 1);
    });
  });

  group('ConfigBuilder', () {
    test('emits sing-box 1.14 schema', () {
      final node = LinkParser.parseLink(
        'vless://u@1.1.1.1:443?security=reality&pbk=k&sid=s&type=tcp'
        '&flow=xtls-rprx-vision#x',
      )!;
      final config = jsonDecode(ConfigBuilder.build(node)) as Map<String, dynamic>;

      // tun inbound uses merged address, no legacy fields
      final inbound = (config['inbounds'] as List).first as Map<String, dynamic>;
      expect(inbound['type'], 'tun');
      expect((inbound['address'] as List), isNotEmpty);
      expect(inbound.containsKey('inet4_address'), isFalse);
      expect(inbound.containsKey('sniff'), isFalse);

      // dns: new typed servers only
      final dns = config['dns'] as Map<String, dynamic>;
      for (final server in (dns['servers'] as List).cast<Map>()) {
        expect(server.containsKey('address'), isFalse,
            reason: 'legacy dns format must not be emitted');
        expect(server['type'], isIn(['https', 'local']));
      }

      // outbounds: proxy + direct only (no block/dns special outbounds)
      final outbounds = (config['outbounds'] as List).cast<Map>();
      expect(outbounds.map((o) => o['type']), everyElement(isIn(['vless', 'direct'])));
      expect(outbounds.first['tag'], 'proxy');

      // route: rule actions instead of legacy inbound sniff
      final route = config['route'] as Map<String, dynamic>;
      final rules = (route['rules'] as List).cast<Map>();
      expect(rules.map((r) => r['action']), containsAll(['sniff', 'hijack-dns']));
      expect(route['default_domain_resolver'], isNotNull);
      expect(route['final'], 'proxy');
    });
  });
}
