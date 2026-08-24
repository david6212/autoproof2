import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:bonnetcheck/core/utils/document_redactor.dart';
import 'package:bonnetcheck/data/models/vehicle_document.dart';

/// Document upload works without Firebase Storage, and cannot skip the
/// redactor.
///
/// The bytes go into a Firestore document, so this is the one upload in the
/// app that does not wait for the Blaze plan. What follows from that is a size
/// ceiling and a rule that every path has to obey; both are pinned here.
void main() {
  final when = DateTime(2026, 8, 24);

  Uint8List photo({int w = 3000, int h = 2000}) {
    final image = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        image.setPixelRgb(x, y, (x * 5) % 256, (y * 11) % 256, (x ^ y) % 256);
      }
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  group('nothing reaches storage unredacted', () {
    test('the repository accepts only a RedactedDocument', () {
      // Not a convention — a type. `saveDocument` cannot be handed raw bytes,
      // so no screen can store a file with its EXIF block and its ID number
      // still in it, however the upload was started.
      final repo =
          File('lib/data/repositories/document_repository.dart').readAsStringSync();

      expect(repo, contains('required RedactedDocument redacted'));
      expect(repo.contains('required Uint8List bytes'), isFalse);
      // And the old Storage path is gone, not merely unused.
      expect(repo.contains('firebase_storage'), isFalse);
    });

    test('the action layer passes the same type through', () {
      final provider = File('lib/presentation/providers/vehicle_provider.dart')
          .readAsStringSync();
      expect(provider, contains('required RedactedDocument redacted'));
    });

    test('the upload flow goes through the redactor screen first', () {
      // Picked file -> RedactDocumentScreen -> save. The screen returns the
      // prepared document, so cancelling it saves nothing at all.
      final screen =
          File('lib/presentation/screens/buyer/vehicle_detail_screen.dart')
              .readAsStringSync();

      final push = screen.indexOf('push<RedactedDocument>');
      final save = screen.indexOf('.save(');
      expect(push, greaterThan(-1));
      expect(save, greaterThan(push), reason: 'redact first, then save');
      expect(screen, contains('if (redacted == null || !mounted) return;'));
    });
  });

  group('the size ceiling is real and is respected', () {
    test('a big photo is squeezed under the Firestore document limit', () {
      final prepared = DocumentRedactor.prepare(photo(), const [])!;

      // 1 MiB is the hard limit for a Firestore document, and the blob shares
      // that document with its own width and height.
      expect(prepared.bytes.lengthInBytes, lessThan(1048576));
      expect(prepared.bytes.lengthInBytes,
          lessThanOrEqualTo(DocumentRedactor.maxBytes));
    });

    test('the repository refuses anything over it rather than truncating', () {
      final repo = File('lib/data/repositories/document_repository.dart')
          .readAsStringSync();
      expect(repo, contains('if (redacted.bytes.lengthInBytes > maxBytes)'));
      expect(repo, contains('throw ArgumentError'));
    });
  });

  group('the record', () {
    test('carries the count of areas the owner blacked out', () {
      final doc = VehicleDocument(
        id: 'd1',
        type: DocumentType.licence,
        title: 'רישיון רכב',
        uploadedByOwnerId: 'u1',
        uploadedAt: when,
        redactedAreas: 2,
      );
      // Would be a lie if it were derived from anything but the save itself.
      expect(doc.wasRedacted, isTrue);
      expect(doc.toFirestore()['redactedAreas'], 2);
      expect(VehicleDocument.fromFirestore(const {'redactedAreas': 2}, 'x')
          .redactedAreas, 2);
    });

    test('an unmarked document does not claim to have been cleaned', () {
      final doc = VehicleDocument(
        id: 'd1',
        type: DocumentType.licence,
        title: 'רישיון רכב',
        uploadedByOwnerId: 'u1',
        uploadedAt: when,
      );
      expect(doc.wasRedacted, isFalse);
    });

    test('a document saved now has no URL, and knows it', () {
      final doc = VehicleDocument(
        id: 'd1',
        type: DocumentType.receipt,
        title: 'חשבונית',
        uploadedByOwnerId: 'u1',
        uploadedAt: when,
      );
      expect(doc.isInline, isTrue);
    });
  });

  test('the file lives below the record, and the rules say so', () {
    // Two claims in one: the list view must not download every scan in the
    // drawer, and a subcollection does not inherit its parent's read rule —
    // so the file's rule has to restate the sharing check, or the switch is
    // decorative.
    final rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /file/{fileId}'));
    expect(rules, contains('attachedDocument(vehicleId, documentId).isSharedWithBuyers == true'));
    expect(rules, contains('vehicleData(vehicleId).isListed == true'));
  });
}
