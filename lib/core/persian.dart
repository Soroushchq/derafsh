/// Persian digit and duration formatting helpers.
library;

const String _faDigits = '۰۱۲۳۴۵۶۷۸۹';

/// Converts ASCII digits in [input] to Persian digits.
String faNum(String input) =>
    input.replaceAllMapped(RegExp(r'[0-9]'), (m) => _faDigits[int.parse(m[0]!)]);

/// Converts an int to Persian digits.
String faInt(int n) => faNum(n.toString());

/// Formats a duration as MM:SS with Persian digits (caller handles LTR wrap).
String faMmSs(Duration d) {
  final m = d.inMinutes.clamp(0, 599);
  final s = d.inSeconds.remainder(60);
  return faNum('${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
}
