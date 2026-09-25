import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/utils/money_formatter.dart';
import 'package:bonnetcheck/core/utils/phone_formatter.dart';

/// The conventions the app settled on 25/09/2026, held in place.
///
/// Before that pass every one of them existed twice, split roughly along the
/// marketplace/garage seam: `נסה שוב` 20 times against `נסו שוב` 21, `שומר...`
/// on one screen and `שומר…` on another, `₪132,000` on thirteen sites and
/// `1,200 ₪` on twelve. Nothing was misspelt — everything was spelt two ways,
/// and a reader moving between two screens reads that as sloppiness without
/// ever naming it.
///
/// This file exists so the next screen written does not reintroduce the mix.
/// If it fails, the fix is almost always to follow the convention rather than
/// to add an exemption.
///
/// Hebrew appears in this codebase only inside string literals — every comment
/// is written in English, bar a handful that quote a string — so stripping
/// comments and scanning the raw text is enough to find user-facing copy
/// without parsing Dart.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      // The five published legal documents are David's lawyer's business, not
      // this suite's. They are internally consistent and were excluded from
      // the wording pass deliberately.
      .where((f) => !f.path.contains('legal_docs'))
      .toList();

  /// The file's source with `//` and `///` comments removed, so a comment that
  /// quotes the wording we banned does not read as an offence.
  String code(File f) => f
      .readAsLinesSync()
      .map((l) {
        final i = l.indexOf('//');
        // The only `//` inside a string in this app is in a URL, and a URL's
        // slashes always follow a colon.
        if (i < 0 || (i > 0 && l[i - 1] == ':')) return l;
        return l.substring(0, i);
      })
      .join('\n');

  List<String> hits(RegExp re, {Set<String> except = const {}}) {
    final found = <String>[];
    for (final file in dartFiles) {
      if (except.any(file.path.contains)) continue;
      final lines = code(file).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (re.hasMatch(lines[i])) found.add('${file.path}:${i + 1}');
      }
    }
    return found;
  }

  /// A whole Hebrew word, not a fragment of a longer one — Hebrew is written
  /// unvocalised, so `בדוק` is also the tail of `לבדוק` and `שמור` is also an
  /// adjective. Both lookarounds are what keeps this check honest.
  RegExp word(String w) => RegExp('(?<![֐-׿])(?:$w)(?![֐-׿])');

  /// A string literal that OPENS with this word: a button label, or an
  /// imperative that starts a sentence.
  RegExp label(String w) => RegExp("'(?:$w)(?: |')");

  group('one reader, and there are several of them', () {
    // The app addresses the reader in the plural — `נסו שוב`, not `נסה שוב`.
    // The login flow is what decided it: the screen's own errors were already
    // plural while the errors thrown underneath it by `auth_repository` were
    // singular, so a user who mistyped a code saw both registers in a row.

    // Unambiguous anywhere in a sentence.
    const inSentence = <String, String>{
      'נסה': 'נסו',
      'בדוק': 'בדקו',
      'הזן': 'הזינו',
      'ודא': 'ודאו',
      'התחבר': 'התחברו',
      'חזור': 'חזרו',
      'אינך': 'אינכם',
    };

    // Words that also read as a noun or an adjective (`עותק שמור`, `רכב שמור`,
    // `הגב` the back), so they are only banned where a string literal opens
    // with them — which is what a button label or an instruction line is.
    const asLabel = <String, String>{
      'שמור': 'שמרו',
      'פרסם': 'פרסמו',
      'הוסף': 'הוסיפו',
      'העלה': 'העלו',
      'הצג': 'הציגו',
      'דווח': 'דווחו',
      'שלח': 'שלחו',
      'סמן': 'סמנו',
      'בחר': 'בחרו',
      'ערוך': 'ערכו',
      'מחק': 'מחקו',
      'הסר': 'הסירו',
      'כתוב': 'כתבו',
      'הגב': 'השיבו',
      'חפש': 'חפשו',
      'עדכן': 'עדכנו',
      'נווט': 'נווטו',
      'התקשר': 'התקשרו',
      'צור': 'צרו',
      'סגור': 'סגרו',
      'בטל': 'בטלו',
      'דלג': 'דלגו',
      'המשך': 'המשיכו',
      'גלוש': 'גלשו',
      // `היה` on its own is also the past tense of "to be", and one string
      // continuation in `claim_vehicle_screen` genuinely opens with it. The
      // construct that was wrong is the invitation.
      'היה הראשון': 'היו הראשונים',
      // `'פתח תקווה'` is a city in two filter lists, not an imperative.
      'פתח(?! תקווה)': 'פתחו',
    };

    for (final e in inSentence.entries) {
      test('"${e.key}" is written "${e.value}"', () {
        expect(hits(word(e.key)), isEmpty,
            reason: 'the app speaks to the reader in the plural: '
                '"${e.key}" → "${e.value}"');
      });
    }

    test('no button or instruction opens with a singular imperative', () {
      final offenders = <String, List<String>>{};
      for (final e in asLabel.entries) {
        final found = hits(label(e.key));
        if (found.isNotEmpty) offenders['${e.key} → ${e.value}'] = found;
      }
      expect(offenders, isEmpty,
          reason: 'buttons carried three registers at once — singular '
              'imperative, plural imperative and gerund. Plural won.');
    });

    test('a possessive or a past tense aimed at the reader is plural too', () {
      // Two exemptions, both in `app_strings.dart` and both deliberate:
      // `tagline` — `הכוח בידיים שלך` is the wordmark's line, and rewriting it
      // is a brand decision, not a proofreading one; and `verifiedAsPrivate`,
      // which carries a legal position, is unreferenced, and is waiting on
      // David.
      expect(
        hits(
          word('שלך|אליך|עליך|אתה|בקרבתך|להודעתך|'
              'שהזנת|שבחרת|שאהבת|שעזרת|שנתת|שילמת|קיבלת|מצאת|שתיעדת|מכרת|סבור'),
          except: {'app_strings.dart'},
        ),
        isEmpty,
      );
    });
  });

  group('one ellipsis character', () {
    test('a Hebrew string never trails off in three dots', () {
      // `שומר...` on the document button against `שומר…` in the fuel sheet —
      // the same word, spelt two ways, three taps apart.
      expect(
        hits(RegExp("'[^']*[֐-׿][^']*\\.\\.\\.")),
        isEmpty,
        reason: 'use the single character … (U+2026), not three periods',
      );
    });
  });

  group('one apostrophe', () {
    test('the geresh and the gershayim are the ASCII marks', () {
      // 41 strings wrote `ק"מ` with a straight quote and exactly one wrote
      // `ק״מ` with the Hebrew gershayim; `צ'אט` was three files against three.
      // Both glyphs are legitimate Hebrew — the app just cannot have both.
      //
      // `place.dart` is exempt: its search normaliser strips BOTH forms on
      // purpose, because place names arrive from the registry either way.
      expect(
        hits(RegExp('[׳״]'), except: {'place.dart'}),
        isEmpty,
        reason: "use ' and \" — the ASCII marks the rest of the app uses",
      );
    });
  });

  group('one money format', () {
    test('the number first, then the sign', () {
      // `₪98,000` is the form that breaks in an RTL line: `₪` is a neutral
      // character, so bidi is free to move it, and `ב-₪1,200` reads worst of
      // all. Only one string in the app ever isolated its price by hand.
      expect(
        hits(RegExp(r'₪ *[0-9$]'), except: {'money_formatter.dart'}),
        isEmpty,
        reason: 'write the amount through MoneyFormatter: "98,000 ₪"',
      );
    });

    test('nobody formats shekels by hand any more', () {
      // Twenty-five literals became one formatter. A fresh `₪` glued onto an
      // interpolation is how the second one starts.
      expect(
        hits(RegExp(r'(\$\{[^}]*\}|\$[a-zA-Z_][a-zA-Z0-9_.]*) ₪'),
            except: {'money_formatter.dart'}),
        isEmpty,
        reason: 'call MoneyFormatter.format / .perLitre instead',
      );
    });

    test('the formatter puts the sign where it was agreed', () {
      expect(MoneyFormatter.format(98000), '98,000 ₪');
      expect(MoneyFormatter.format(950), '950 ₪');
      expect(MoneyFormatter.thousands(1200), '1,200');
      expect(MoneyFormatter.perLitre(7.19), '7.19 ₪ לליטר');
    });
  });

  group('a number is shown in the form its owner typed it', () {
    test('E.164 never reaches the reader', () {
      // `שלחנו קוד בן 6 ספרות אל +972501234567` was the first sentence a new
      // user read after handing over their number.
      expect(
        hits(RegExp(r"'[^']*\$\{?[a-zA-Z_.]*phoneE164")),
        isEmpty,
        reason: 'render it through PhoneFormatter.local',
      );
    });

    test('the formatter gives back the local form', () {
      expect(PhoneFormatter.local('+972501234567'), '050-1234567');
      expect(PhoneFormatter.local('0501234567'), '050-1234567');
      expect(PhoneFormatter.local('+97231234567'), '03-1234567');
      // Anything it cannot read is shown as it is, never mangled.
      expect(PhoneFormatter.local('+15551234567'), '+15551234567');
      expect(PhoneFormatter.local(null), '');
    });
  });

  group('a count agrees with its noun', () {
    test('no interpolated count sits in front of a bare plural', () {
      // "לרכב יש 1 רשומות טיפול", "בעוד 1 ימים". The codebase already wrote
      // the singular branch correctly in twelve places and simply skipped it
      // in twenty-eight others — including every relative-time helper, each of
      // which broke at its own one-hour and one-day boundary.
      //
      // A line that interpolates a count before one of these nouns has to
      // carry the `== 1` branch, which in a wrapped ternary can sit a couple
      // of lines above it.
      const plurals = [
        'ימים',
        'שעות',
        'דקות',
        'חודשים',
        'שנים',
        'רשומות טיפול',
        'קריאות שירות',
        'תוצאות',
        'ביקורות',
        'תחנות',
        'מכונים',
        'רכבים)',
        'מסננים',
        'אזורים',
        'ממצאים',
      ];
      // Three lines interpolate a count that cannot be 1, each behind a
      // documented floor: `Place.minRatingsToShow` is 3 and the line is inside
      // `if (place.hasEnoughRatings)`; `MarketStats.minSample` is 8 and the
      // card returns null below it; and the "תיק מתועד" sentence only renders
      // when `badged`, which needs 3 records across 6 months. A singular
      // branch there would be unreachable code.
      const guardedByAFloor = {
        'place_detail_screen.dart',
        'market_price_band.dart',
        'publish_from_vehicle_screen.dart',
      };
      final count = RegExp(r'== -?1\b');
      final offenders = <String>[];
      for (final file in dartFiles) {
        if (guardedByAFloor.any(file.path.contains)) continue;
        final lines = code(file).split('\n');
        for (var i = 0; i < lines.length; i++) {
          final hasCount = plurals.any((n) => RegExp(
                  r'(\$\{[^}]*\}|\$[a-zA-Z_][a-zA-Z0-9_.]*) ' + RegExp.escape(n))
              .hasMatch(lines[i]));
          if (!hasCount) continue;
          // "X מתוך Y רשומות" agrees with Y, which is a constant floor here,
          // not with the interpolated X.
          if (lines[i].contains('מתוך')) continue;
          final window =
              lines.sublist(i - 4 < 0 ? 0 : i - 4, i + 2 > lines.length ? lines.length : i + 2).join('\n');
          if (count.hasMatch(window)) continue;
          offenders.add('${file.path}:${i + 1}');
        }
      }
      expect(offenders, isEmpty,
          reason: 'give the count a singular branch, the way '
              'documented_history_card and car_photo_gallery already do');
    });
  });
}
