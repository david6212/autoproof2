import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/car_note_model.dart';

/// The visitor note is now a closed bank of inspection findings, and nothing
/// else.
///
/// Two things were removed on 24/08/2026 and neither should come back without
/// a decision: the free-text field, and every way of reporting the SELLER.
/// What is left describes the car — and the whole reason a closed list exists
/// is that two people looking at the same vehicle should be able to tick the
/// same box.
void main() {
  group('the bank', () {
    test('covers what a person actually checks, in every group', () {
      // A bank missing a whole area of the car sends people looking for the
      // free-text field that is not there any more.
      for (final g in NoteGroup.values) {
        expect(NoteTagX.inGroup(g), isNotEmpty, reason: g.label);
      }
      expect(NoteTag.values.length, greaterThanOrEqualTo(20));
    });

    test('every option belongs to exactly one group', () {
      final grouped = [
        for (final g in NoteGroup.values) ...NoteTagX.inGroup(g),
      ];
      expect(grouped.length, NoteTag.values.length);
      expect(grouped.toSet().length, NoteTag.values.length);
    });

    test('the stored ids are unique and stable-looking', () {
      // The id is what lands in Firestore. Two options sharing one would merge
      // silently; a localised one would break the day a label is reworded.
      final ids = [for (final t in NoteTag.values) t.id];
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(id), isTrue, reason: id);
      }
    });

    test('an id this build does not know is dropped, not rendered raw', () {
      final note = CarNote.fromFirestore(const {
        'tags': ['rust', 'invented_by_a_future_build'],
      }, 'n1');
      expect(note.tags, [NoteTag.rust]);
    });

    test('a note with no ticks has nothing to show', () {
      final note = CarNote.fromFirestore(const {'tags': <String>[]}, 'n1');
      expect(note.hasVisibleContent, isFalse);
    });
  });

  group('what the options may say', () {
    test('none of them is about the seller', () {
      // The whole "who did you meet" feature was removed. A bank option that
      // described the person would put it back one chip at a time.
      for (final t in NoteTag.values) {
        for (final word in ['מוכר', 'סוחר', 'סוכן', 'שיקר', 'הסתיר', 'רימה']) {
          expect(t.label.contains(word), isFalse,
              reason: '${t.id}: "${t.label}" names the seller');
        }
      }
    });

    test('none of them draws the conclusion for the reader', () {
      // "סימני חלודה" is an observation; "חלודה קשה" is a verdict. The buyer
      // decides what a finding means, the same rule the active-warnings copy
      // follows.
      for (final t in NoteTag.values) {
        for (final word in ['חמור', 'קשה', 'מסוכן', 'גרוע', 'חשוד']) {
          expect(t.label.contains(word), isFalse, reason: t.label);
        }
        expect(t.label.contains('!'), isFalse);
      }
    });

    test('reassuring findings exist too, so this is not a complaint box', () {
      final positive = NoteTag.values.where((t) => t.isPositive);
      expect(positive.length, greaterThanOrEqualTo(4));
      // And all of them are checks against the advert, not opinions.
      for (final t in positive) {
        expect(t.group, NoteGroup.listing, reason: t.id);
      }
    });
  });

  group('nothing free-typed survives', () {
    test('the model has no text field and no moderation flag', () {
      final src =
          File('lib/data/models/car_note_model.dart').readAsStringSync();
      for (final gone in ['otherText', 'approved', 'sellerFlag', 'flagLabel']) {
        expect(src.contains(gone), isFalse, reason: gone);
      }
    });

    test('the write path cannot carry text either', () {
      // Enforced at the boundary, not by the sheet: a future screen calling
      // addNote gets tags or nothing.
      final repo =
          File('lib/data/repositories/car_repository.dart').readAsStringSync();
      final at = repo.indexOf('Future<void> addNote(');
      expect(at, greaterThan(-1));
      final signature = repo.substring(at, repo.indexOf('}', at));
      expect(signature.contains('otherText'), isFalse);
      expect(signature.contains('sellerFlag'), isFalse);
      expect(signature, contains('List<NoteTag> tags'));
    });

    test('the sheet offers chips and no text field', () {
      final sheet = File('lib/presentation/widgets/car_notes_section.dart')
          .readAsStringSync();
      expect(sheet.contains('TextField('), isFalse);
      expect(sheet.contains('TextEditingController'), isFalse);
    });
  });

  test('no user-facing string carries an emoji', () {
    // Found on the live site, 24/08: the notes empty state ended in an empty
    // box. The app bundles Heebo and Poppins and nothing else — Google Fonts
    // was removed for a licence reason, see bundled_fonts_test — so the web
    // engine has no font to fall back to for an emoji and draws the box.
    //
    // Checked by code point rather than by regex, because a regex for this
    // range is mostly escapes and the next person has to trust it.
    bool isEmoji(int r) =>
        (r >= 0x1F000 && r <= 0x1FAFF) ||
        (r >= 0x2600 && r <= 0x27BF) ||
        r == 0xFE0F;

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Comments are exempt: an emoji marking a warning to a developer
        // never reaches a screen.
        final code = lines[i].split('//').first;
        expect(code.runes.any(isEmoji), isFalse,
            reason: '${file.path}:${i + 1} — ${lines[i].trim()}');
      }
    }
  });

  test('the "who did you meet" feature is gone from the codebase', () {
    // Model, card, providers, repository methods and the Firestore rule. A
    // leftover provider would keep a dead subcollection readable and would be
    // the obvious thing to wire back up by accident.
    expect(File('lib/data/models/seller_encounter.dart').existsSync(), isFalse);
    expect(
        File('lib/presentation/widgets/seller_encounter_card.dart').existsSync(),
        isFalse);

    for (final path in [
      'lib/presentation/providers/cars_provider.dart',
      'lib/data/repositories/car_repository.dart',
      'lib/presentation/screens/buyer/car_detail_screen.dart',
      'lib/presentation/widgets/car/car_active_warnings.dart',
      'firestore.rules',
    ]) {
      expect(File(path).readAsStringSync().toLowerCase().contains('encounter'),
          isFalse,
          reason: path);
    }
  });
}
