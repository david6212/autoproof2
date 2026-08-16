import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/constants/legal_docs.dart';
import 'package:bonnetcheck/core/constants/legal_info.dart';

/// The five legal documents were written weeks before they could be shown:
/// they name the operator and a contact address, and naming an entity that
/// does not exist is worse than publishing nothing. So they stayed behind
/// [LegalInfo.isPublished] until both were real.
///
/// They are real now. These check that turning the gate on did not leave a
/// hole where an empty value used to be — a policy reading "מופעל על ידי ."
/// is the kind of thing nobody notices until a user screenshots it.
void main() {
  Iterable<String> everyParagraph() sync* {
    for (final doc in LegalDocs.all) {
      yield doc.title;
      yield doc.summary;
      for (final section in doc.sections) {
        yield section.heading;
        yield* section.paragraphs;
      }
    }
  }

  test('the documents are published', () {
    expect(LegalInfo.isPublished, isTrue);
    expect(LegalInfo.operatorName.trim(), isNotEmpty);
    expect(LegalInfo.contactEmail.trim(), isNotEmpty);
  });

  test('all five are there', () {
    expect(LegalDocs.all, hasLength(5));
    expect(
      LegalDocs.all.map((d) => d.id).toSet(),
      {'terms', 'privacy', 'cookies', 'removal', 'complaints'},
    );
  });

  test('the operator line names somebody', () {
    final line = LegalInfo.operatorLine;
    expect(line, contains(LegalInfo.operatorName));
    // A private individual publishes no company number and no home address,
    // and the line must not carry the punctuation that would have separated
    // them.
    expect(line.trim(), isNot(endsWith('·')));
    expect(line, isNot(contains('()')));
  });

  test('no paragraph was left with a hole where a value goes', () {
    for (final p in everyParagraph()) {
      expect(p.contains('  '), isFalse, reason: 'double space in: $p');
      expect(p.contains('על ידי .'), isFalse, reason: 'empty operator in: $p');
      expect(p.contains(': .'), isFalse, reason: 'empty value in: $p');
      expect(p.trim(), isNotEmpty);
      // An unresolved interpolation would show up literally.
      expect(p.contains(r'${'), isFalse, reason: 'raw interpolation in: $p');
    }
  });

  test('the contact address actually appears in the documents', () {
    // The privacy policy and the removal policy both promise a route for
    // deletion requests. If the address is not in the text, the promise is to
    // nobody.
    final all = everyParagraph().join('\n');
    expect(all, contains(LegalInfo.contactEmail));
    expect(all, contains(LegalInfo.operatorName));
  });

  test('one address, not two', () {
    // Two mailboxes means one of them eventually stops being read — in a
    // document that promises a way to delete personal data.
    final all = everyParagraph().join('\n');
    final addresses = RegExp(r'[\w.\-]+@[\w.\-]+\.\w+')
        .allMatches(all)
        // Hebrew prefixes attach with a maqaf — "ל-support@..." — and the
        // hyphen would otherwise read as part of the address.
        .map((m) => m.group(0)!.replaceFirst(RegExp(r'^[-–]+'), ''))
        .toSet();
    expect(addresses, {LegalInfo.contactEmail});
  });
}
