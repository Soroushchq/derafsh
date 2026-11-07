import 'package:flutter_test/flutter_test.dart';

import 'package:drf/core/persian.dart';

void main() {
  test('faNum converts ASCII digits to Persian', () {
    expect(faNum('12:34'), '۱۲:۳۴');
    expect(faNum('no digits'), 'no digits');
  });

  test('faInt', () {
    expect(faInt(0), '۰');
    expect(faInt(48), '۴۸');
  });

  test('faMmSs pads and converts', () {
    expect(faMmSs(const Duration(minutes: 7, seconds: 5)), '۰۷:۰۵');
    expect(faMmSs(const Duration(seconds: 59)), '۰۰:۵۹');
  });
}
