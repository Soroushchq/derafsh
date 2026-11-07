/// Source catalog: the list of subscription endpoints Derafsh can use.
///
/// The catalog ships as an asset (`assets/data/sources.json`) and can later
/// be overridden by the Worker (`/v1/config`). Free tier only activates
/// [SourceCatalog.freeSourceId]; every other entry is premium-locked.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class DrfSource {
  const DrfSource({
    required this.id,
    required this.name,
    required this.url,
    required this.locked,
  });

  final int id;
  final String name;
  final String url;
  final bool locked;
}

class SourceCatalog {
  SourceCatalog._(this.sources, this.freeSourceId);

  final List<DrfSource> sources;
  final int freeSourceId;

  static SourceCatalog? _cache;

  /// Empty fallback (used if the asset is unreadable; connect is disabled).
  static SourceCatalog empty() => SourceCatalog._(const [], 1);

  /// Loads the bundled catalog (cached after first call).
  static Future<SourceCatalog> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/data/sources.json');
    final catalog = parse(raw);
    _cache = catalog;
    return catalog;
  }

  /// Parses catalog JSON. Exposed for tests.
  static SourceCatalog parse(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final freeId = (map['free_source_id'] as num?)?.toInt() ?? 1;
    final list = (map['sources'] as List).cast<Map<String, dynamic>>();
    final sources = list
        .map((e) => DrfSource(
              id: (e['id'] as num).toInt(),
              name: e['name'] as String,
              url: e['url'] as String,
              locked: (e['id'] as num).toInt() != freeId,
            ))
        .toList(growable: false);
    return SourceCatalog._(sources, freeId);
  }

  int get length => sources.length;

  bool get isEmpty => sources.isEmpty;

  DrfSource operator [](int index) => sources[index];

  /// The source the user may connect to, given premium state.
  DrfSource effectiveSource(int selectedIndex, bool premium) {
    if (premium && sources.isNotEmpty) {
      return sources[selectedIndex.clamp(0, sources.length - 1)];
    }
    return sources.firstWhere(
      (s) => s.id == freeSourceId,
      orElse: () => sources.first,
    );
  }
}
