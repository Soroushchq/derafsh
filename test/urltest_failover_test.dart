/// Health-checked pool failover (v1.0.2).
///
/// Why: v1.0.0/1.0.1 handed sing-box exactly ONE outbound. sing-box never
/// had anything to choose from, so a dead or newly blocked node meant a
/// dead tunnel with no recovery. The fix is sing-box's native `urltest`
/// outbound group: every member is probed through its real protocol and
/// traffic rides the alive member with the lowest latency, re-checked on
/// an interval.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:drf/data/config_builder.dart';
import 'package:drf/data/link_parser.dart';
import 'package:drf/data/node_resolver.dart';

DrfNode? _parse(String link) => LinkParser.parseLink(link);

List<DrfNode> _nodesByRank() {
  final reality = _parse(
    'vless://u@1.1.1.1:443?security=reality&pbk=k&sid=s&type=tcp'
    '&flow=xtls-rprx-vision#reality-node',
  )!;
  final trojan = _parse('trojan://pw@2.2.2.2:443#trojan-node')!;
  final ws = _parse(
    'vless://u@3.3.3.3:80?security=none&type=ws&path=%2Fws#ws-node',
  )!;
  return [ws, reality, trojan]; // deliberately NOT rank-ordered
}

Map<String, dynamic> _configJson(String config) =>
    jsonDecode(config) as Map<String, dynamic>;

List<Map<String, dynamic>> _outbounds(Map<String, dynamic> config) =>
    (config['outbounds'] as List).cast<Map<String, dynamic>>();

void main() {
  group('ConfigBuilder.buildPool', () {
    test('emits a urltest group over rank-ordered members', () {
      final nodes = SingBoxNodeResolver.pickTopNodes(_nodesByRank(), 24);
      final config = _configJson(ConfigBuilder.buildPool(nodes));

      final group = _outbounds(config).first;
      expect(group['type'], 'urltest');
      expect(group['tag'], 'proxy');
      expect(group['url'], ConfigBuilder.probeUrl);
      expect(group['interval'], isA<String>());
      expect(group['tolerance'], isA<int>());

      // members carry pool tags and keep best-first order (reality > trojan > ws)
      final memberTags = (group['outbounds'] as List).cast<String>();
      expect(memberTags, ['n1', 'n2', 'n3']);
      final byTag = {
        for (final o in _outbounds(config).skip(1)) o['tag'] as String: o,
      };
      expect(byTag['n1']!['type'], 'vless'); // reality — highest rank
      expect(byTag['n2']!['type'], 'trojan');
      expect(byTag['n3']!['type'], 'vless'); // ws — lowest rank

      // every referenced member exists; tags unique; direct stays
      final allTags = _outbounds(config).map((o) => o['tag']).toList();
      expect(allTags.length, allTags.toSet().length);
      for (final t in memberTags) {
        expect(byTag.containsKey(t), isTrue, reason: 'member $t missing');
      }
      expect(allTags, contains('direct'));

      // routing still points at the group, DNS still detours through it
      expect((config['route'] as Map<String, dynamic>)['final'], 'proxy');
      final dnsServers =
          (config['dns'] as Map<String, dynamic>)['servers'] as List;
      expect(
        dnsServers.cast<Map>().firstWhere((s) => s['tag'] == 'dns-proxy')['detour'],
        'proxy',
      );
    });

    test('caps the pool and keeps member tags unique', () {
      final many = [
        for (var i = 0; i < 40; i++)
          _parse('trojan://pw@10.0.0.$i:443#node-$i')!,
      ];
      final config = _configJson(ConfigBuilder.buildPool(many));

      final group = _outbounds(config).first;
      final memberTags = (group['outbounds'] as List).cast<String>();
      expect(memberTags.length, ConfigBuilder.maxPoolMembers);
      expect(memberTags.toSet().length, ConfigBuilder.maxPoolMembers);
      // one group + members + direct
      expect(_outbounds(config).length, ConfigBuilder.maxPoolMembers + 2);
    });

    test('a single node keeps the legacy single-outbound shape', () {
      final node = _parse('trojan://pw@2.2.2.2:443#only')!;
      final config = _configJson(ConfigBuilder.buildPool([node]));

      final outbounds = _outbounds(config);
      expect(outbounds.length, 2); // proxy + direct
      expect(outbounds.first['type'], 'trojan');
      expect(outbounds.first['tag'], 'proxy');
      expect(outbounds.map((o) => o['type']), isNot(contains('urltest')));
    });

    test('rejects an empty pool', () {
      expect(() => ConfigBuilder.buildPool(const []), throwsArgumentError);
    });
  });

  group('SingBoxNodeResolver', () {
    test('resolve hands the ranked pool to the config builder', () async {
      const body = 'vless://u@1.1.1.1:443?security=reality&pbk=k&sid=s'
          '&type=tcp&flow=xtls-rprx-vision#r\n'
          'trojan://pw@2.2.2.2:443#t\n';
      final client = MockClient(
        (request) async => http.Response(body, 200),
      );
      final resolver = SingBoxNodeResolver(client: client);
      addTearDown(resolver.dispose);

      final resolved = await resolver.resolve('https://sub.example/s');
      final config = _configJson(resolved.config);

      final group = _outbounds(config).first;
      expect(group['type'], 'urltest');
      expect((group['outbounds'] as List).length, 2);
    });
  });
}
