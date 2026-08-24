import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:bonnetcheck/core/utils/document_redactor.dart';

/// The redactor is the only part of document upload that makes a promise, so
/// it is the part that has to be provable.
///
/// The promise is narrow on purpose: the owner marks what to hide, the app
/// destroys those pixels, and the EXIF block goes whether or not anyone asked.
/// Nothing here claims to FIND an ID number — see the class comment for why
/// that claim cannot be made in Hebrew.
void main() {
  /// A picture with a bright red patch where "the ID number" is, so a test can
  /// ask whether that patch survived.
  Uint8List sample({int w = 2400, int h = 1600, bool withExif = true}) {
    final image = img.Image(width: w, height: h);
    // Noise, not a flat fill: a flat image compresses to almost nothing and
    // would make the size tests pass for the wrong reason.
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        image.setPixelRgb(x, y, (x * 7) % 256, (y * 13) % 256, (x + y) % 256);
      }
    }
    img.fillRect(image,
        x1: (w * 0.10).round(),
        y1: (h * 0.10).round(),
        x2: (w * 0.30).round(),
        y2: (h * 0.20).round(),
        color: img.ColorRgb8(255, 0, 0));
    if (withExif) {
      image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(32, 1);
      image.exif.imageIfd['Model'] = img.IfdValueAscii('Pixel');
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 95));
  }

  const idPatch = RedactionBox(left: 0.08, top: 0.08, width: 0.25, height: 0.15);

  /// Is the marked area actually black in the saved file?
  bool patchIsBlack(Uint8List bytes, RedactionBox box) {
    final out = img.decodeImage(bytes)!;
    final x = ((box.left + box.width / 2) * out.width).round();
    final y = ((box.top + box.height / 2) * out.height).round();
    final p = out.getPixel(x, y);
    // JPEG is lossy, so "black" is a neighbourhood, not a value.
    return p.r < 24 && p.g < 24 && p.b < 24;
  }

  test('a marked area comes back black, in the pixels', () {
    final result = DocumentRedactor.prepare(sample(), [idPatch])!;

    expect(patchIsBlack(result.bytes, idPatch), isTrue);
    expect(result.boxCount, 1);
  });

  test('the original is not recoverable — the red patch is gone', () {
    // The point of burning rather than drawing: a rectangle stored beside the
    // image is a curtain, and a buyer who is shown the document holds the
    // bytes.
    final before = img.decodeImage(sample())!;
    final at = before.getPixel(
        (before.width * 0.20).round(), (before.height * 0.15).round());
    expect(at.r, greaterThan(200), reason: 'red before redaction');

    final result = DocumentRedactor.prepare(sample(), [idPatch])!;
    final after = img.decodeImage(result.bytes)!;
    final now = after.getPixel(
        (after.width * 0.20).round(), (after.height * 0.15).round());
    expect(now.r, lessThan(24));
  });

  test('EXIF goes even when nothing was marked', () {
    // The one thing the app removes on its own. A photo of a licence taken on
    // the driveway carries the driveway's coordinates, the owner cannot see
    // that in the picture and would never think to paint over it.
    final result = DocumentRedactor.prepare(sample(), const [])!;
    final out = img.decodeImage(result.bytes)!;

    expect(out.exif.gpsIfd.isEmpty, isTrue);
    expect(out.exif.imageIfd.isEmpty, isTrue);
    expect(result.boxCount, 0);
  });

  test('the result fits inside a Firestore document', () {
    // 1 MiB is the hard ceiling, and the metadata shares the document.
    final result = DocumentRedactor.prepare(sample(w: 4000, h: 3000), const [])!;

    expect(result.bytes.lengthInBytes, lessThanOrEqualTo(DocumentRedactor.maxBytes));
    expect(result.bytes.lengthInBytes, lessThan(1048576));
  });

  test('a document is not enlarged, and stays readable', () {
    final result = DocumentRedactor.prepare(sample(w: 4000, h: 3000), const [])!;

    expect(result.width, lessThanOrEqualTo(DocumentRedactor.maxDimension));
    // Quality is allowed to fall, but only so far: a document that cannot be
    // read is not worth storing.
    expect(result.quality, greaterThanOrEqualTo(40));
  });

  test('a small scan is left at its own size', () {
    final result = DocumentRedactor.prepare(sample(w: 800, h: 600), const [])!;
    expect(result.width, 800);
    expect(result.height, 600);
  });

  test('a portrait scan is measured on its long edge', () {
    final result = DocumentRedactor.prepare(sample(w: 1600, h: 2400), const [])!;
    expect(result.height, DocumentRedactor.maxDimension);
    expect(result.width, lessThan(DocumentRedactor.maxDimension));
  });

  test('a box dragged off the edge still burns, clamped', () {
    const runaway =
        RedactionBox(left: 0.9, top: 0.9, width: 0.5, height: 0.5);
    final result = DocumentRedactor.prepare(sample(), [runaway])!;

    expect(result.boxCount, 1);
    expect(patchIsBlack(result.bytes, runaway.normalised), isTrue);
  });

  test('a stray tap is not a redaction', () {
    // A press with no drag would otherwise be recorded as "1 area hidden",
    // which is a count the owner is entitled to trust.
    const tap = RedactionBox(left: 0.5, top: 0.5, width: 0.001, height: 0.001);
    final result = DocumentRedactor.prepare(sample(), [tap])!;

    expect(result.boxCount, 0);
  });

  test('something that is not an image is refused, not saved empty', () {
    final junk = Uint8List.fromList(List.filled(500, 7));
    expect(DocumentRedactor.prepare(junk, const []), isNull);
  });

  test('several areas all burn', () {
    const boxes = [
      RedactionBox(left: 0.05, top: 0.05, width: 0.2, height: 0.1),
      RedactionBox(left: 0.6, top: 0.7, width: 0.2, height: 0.1),
    ];
    final result = DocumentRedactor.prepare(sample(), boxes)!;

    expect(result.boxCount, 2);
    for (final b in boxes) {
      expect(patchIsBlack(result.bytes, b), isTrue);
    }
  });
}
