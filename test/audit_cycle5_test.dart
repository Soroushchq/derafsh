/// Audit cycle 5 regressions:
/// - B11: KavianiStarPainter drew the rotating ray crown with the path
///   geometry centered on `c` (widget center) AFTER `translate(c)` +
///   `rotate(θ)`, so device position was `c + R·c + R·dir·r` — the crown
///   was rendered one full center-offset away from the star and orbited
///   the true center as it spun. The fix adds the counter-translate
///   pivot idiom so rays rotate around the star center.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:drf/design/kaviani_star.dart';

const int _dim = 200;

Future<Uint8List> _renderStarRgba() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final painter = KavianiStarPainter(
    mood: StarMood.radiant,
    spin: 0.0,
    glow: 0.0,
    unfold: 1.0,
  );
  painter.paint(canvas, ui.Size(_dim.toDouble(), _dim.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(_dim, _dim);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

int _alphaAt(Uint8List bytes, int x, int y) => bytes[(y * _dim + x) * 4 + 3];

void main() {
  test(
    'B11: ray crown is painted around the star center, not offset by the pivot',
    () async {
      final bytes = await _renderStarRgba();

      // Harness sanity: the center disc of the star itself must be visible.
      // (rOut·0.09 disc at the exact center, alpha 0.95.)
      expect(
        _alphaAt(bytes, 100, 100),
        greaterThan(0),
        reason: 'star center disc must be rendered by the harness',
      );

      // With spin = 0 the crown rotation is identity, so every ray must sit
      // exactly where its geometry says: a sliver from radius ~72 to ~96.5
      // around c = (100, 100).
      // Ray i=4 (ang = π, −x direction): covers x ≈ 3.5..28 at y = 100.
      // The halo rings (radius 91.1/105.4, thin strokes), ring dots
      // (radius 91.1, angles −67.5°+45°k — never 180°) and the glow
      // (alpha 0 with glow: 0) paint nothing at (5, 100); only the ray does.
      expect(
        _alphaAt(bytes, 5, 100),
        greaterThan(0),
        reason: 'the −x ray of the crown must be painted left of the star',
      );

      // Ray i=0 (ang = 0, +x direction): covers x ≈ 172..196.5 at y = 100.
      expect(
        _alphaAt(bytes, 185, 100),
        greaterThan(0),
        reason: 'the +x ray of the crown must be painted right of the star',
      );
    },
  );
}
