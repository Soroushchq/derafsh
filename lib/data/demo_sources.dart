/// Demo source list for PART 1.
///
/// TODO(part3): the real list (names, statuses, locks) is fetched from the
/// Worker endpoint `POST /v1/sources` and never hard-coded here.
class DrfSource {
  const DrfSource({required this.name, required this.locked});

  final String name;
  final bool locked;
}

const List<DrfSource> demoSources = [
  DrfSource(name: 'آزاد', locked: false),
  DrfSource(name: 'سیمرغ', locked: true),
  DrfSource(name: 'کاوه', locked: true),
  DrfSource(name: 'شهاب', locked: true),
  DrfSource(name: 'ستاره', locked: true),
];

/// Persian display of "a از b فعال".
String activeCountLabel(int active, int total) => '$active از $total فعال';
