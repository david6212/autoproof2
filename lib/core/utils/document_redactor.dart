import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// One area the owner painted over, in FRACTIONS of the image (0..1).
///
/// Fractions rather than pixels because the boxes are drawn on a preview that
/// has been scaled to fit a phone screen, and burned into an image that has
/// been scaled to fit a Firestore document. Neither scale is known to the
/// other, and a pixel rectangle would land somewhere else in both.
class RedactionBox {
  const RedactionBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  /// Clamped to the image, so a drag that ran off the edge still burns.
  RedactionBox get normalised {
    final l = left.clamp(0.0, 1.0);
    final t = top.clamp(0.0, 1.0);
    return RedactionBox(
      left: l,
      top: t,
      width: width.clamp(0.0, 1.0 - l),
      height: height.clamp(0.0, 1.0 - t),
    );
  }

  bool get isMeaningful => width > 0.005 && height > 0.005;

  Map<String, dynamic> toMap() =>
      {'left': left, 'top': top, 'width': width, 'height': height};
}

/// The result of preparing a document for storage.
class RedactedDocument {
  const RedactedDocument({
    required this.bytes,
    required this.width,
    required this.height,
    required this.boxCount,
    required this.quality,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  /// How many areas were painted over. Shown to the owner, and stored on the
  /// record, so "2 areas hidden" is a fact rather than a reassurance.
  final int boxCount;

  /// The JPEG quality it took to fit. Only interesting when debugging why a
  /// scan came out soft.
  final int quality;
}

/// Burns black boxes into a document image and squeezes it into a Firestore
/// document.
///
/// **Why the boxes are burned rather than drawn over.** A rectangle stored
/// beside the image and painted by the viewer is a curtain: anyone who reads
/// the bytes — and a buyer the document is shared with can — pulls it aside.
/// The only redaction that survives being downloaded is one that destroyed the
/// pixels. That is what this does, and it is why the original is never kept.
///
/// **What it removes without being asked, and can promise:** the EXIF block.
/// A photo of a licence taken on the driveway carries the coordinates of the
/// driveway, and the owner cannot see that in the picture, cannot paint over
/// it, and would never think to. Re-encoding from raw pixels leaves no
/// metadata of any kind.
///
/// **What it cannot promise:** finding the sensitive parts by itself. Reading
/// a Hebrew address off a photograph needs OCR that does not exist on-device
/// for Hebrew, and a redactor that silently misses one is worse than no
/// redactor, because the owner shares the document believing it was cleaned.
/// So the owner marks; the app burns.
class DocumentRedactor {
  DocumentRedactor._();

  /// Firestore's ceiling is 1 MiB per document, counting field names, the
  /// blob's own length prefix and every other field beside it. This leaves
  /// room and is not a limit worth spending the last 10% of.
  static const maxBytes = 900000;

  /// A licence or an invoice is read, not enlarged. 1600px on the long edge
  /// keeps small print legible and is most of what makes the file fit.
  static const maxDimension = 1600;

  /// Qualities to try, in order. Below 40 the text starts to break up, and a
  /// document that cannot be read is not worth storing.
  static const _qualities = [80, 70, 60, 50, 40];

  /// Returns null when the image cannot be decoded, or cannot be made to fit
  /// even at the smallest size this will accept. The caller says so; it must
  /// not save a truncated file.
  static RedactedDocument? prepare(
    Uint8List source,
    List<RedactionBox> boxes,
  ) {
    final decoded = img.decodeImage(source);
    if (decoded == null) return null;

    final kept = [
      for (final b in boxes)
        if (b.normalised.isMeaningful) b.normalised,
    ];

    var working = _fit(decoded, maxDimension);

    // Three passes: full size, then two steps down. Each pass tries every
    // quality before shrinking, because a smaller picture of a document is a
    // worse trade than a softer one.
    var longEdge = maxDimension;
    for (var attempt = 0; attempt < 3; attempt++) {
      final painted = _paint(working, kept);
      for (final q in _qualities) {
        final encoded = img.encodeJpg(painted, quality: q);
        if (encoded.lengthInBytes <= maxBytes) {
          return RedactedDocument(
            bytes: encoded,
            width: painted.width,
            height: painted.height,
            boxCount: kept.length,
            quality: q,
          );
        }
      }
      longEdge = (longEdge * 0.75).round();
      working = _fit(decoded, longEdge);
    }
    return null;
  }

  /// Scales the long edge down to [longEdge]. Never up: enlarging a small scan
  /// adds bytes and no detail.
  static img.Image _fit(img.Image src, int longEdge) {
    final longest = src.width > src.height ? src.width : src.height;
    if (longest <= longEdge) return img.Image.from(src);
    return src.width >= src.height
        ? img.copyResize(src, width: longEdge)
        : img.copyResize(src, height: longEdge);
  }

  static img.Image _paint(img.Image src, List<RedactionBox> boxes) {
    // A copy per attempt: painting the same image twice would be harmless, but
    // shrinking a painted image spreads the black edges into the text beside
    // them, and the boxes would drift.
    final out = img.Image.from(src);

    // Dropped explicitly rather than trusted to the encoder. This is the one
    // piece of sensitive data the redactor removes on its own.
    out.exif = img.ExifData();

    final black = img.ColorRgb8(0, 0, 0);
    for (final b in boxes) {
      final x1 = (b.left * out.width).round();
      final y1 = (b.top * out.height).round();
      final x2 = ((b.left + b.width) * out.width).round() - 1;
      final y2 = ((b.top + b.height) * out.height).round() - 1;
      if (x2 < x1 || y2 < y1) continue;
      img.fillRect(out, x1: x1, y1: y1, x2: x2, y2: y2, color: black);
    }
    return out;
  }
}
