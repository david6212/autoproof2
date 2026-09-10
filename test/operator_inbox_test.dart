import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/constants/app_config.dart';
import 'package:bonnetcheck/data/repositories/operator_inbox_repository.dart';

/// The fourteen-day promise, and the machinery behind it.
///
/// The privacy policy, the content-removal policy and the complaints procedure
/// all say *"נשיב תוך 14 ימים"*. Both collections that receive those requests
/// were `allow read: if false` — unreadable by everybody, the operator
/// included — so a request arrived and waited for somebody to remember to open
/// a console. Failing to answer a data-subject request is an actual breach,
/// and for a product built on never claiming more than it performs it was the
/// wrong promise to leave unkept.
void main() {
  final rules = File('firestore.rules').readAsStringSync();

  /// The body of one `match` block.
  ///
  /// Not `indexOf('}')` — the first brace in `match /note_reports/{reportId} {`
  /// closes the wildcard, not the block, and slicing there returns the match
  /// line itself. Reading to the next `match /` is crude and correct here.
  String block(String collection) {
    final start = rules.indexOf('match /$collection/');
    expect(start, greaterThan(-1), reason: collection);
    final after = rules.indexOf('match /', start + 8);
    return after == -1 ? rules.substring(start) : rules.substring(start, after);
  }

  group('who may read a complaint', () {
    test('the operator, and the rules say who that is', () {
      expect(rules, contains('function isOperator()'));
      expect(rules, contains(AppConfig.operatorEmail),
          reason: 'the rules and AppConfig must name the same account');
    });

    test('an unverified email is not enough', () {
      // A token carries whatever email the account claimed. Without the
      // verification flag, anyone who signs up with the operator's address at
      // a provider that does not verify would read other people's complaints.
      final fn = rules.substring(
        rules.indexOf('function isOperator()'),
        rules.indexOf('function isSignedIn()'),
      );
      expect(fn, contains('email_verified'));
    });

    test('both collections are open to the operator and nobody else', () {
      for (final collection in const ['note_reports', 'data_corrections']) {
        final body = block(collection);
        expect(body, contains('allow read: if isOperator()'), reason: collection);
        expect(body.contains('allow read: if false'), isFalse,
            reason: '$collection was unreadable and the promise had no delivery');
      }
    });
  });

  group('what the operator may change', () {
    test('a timestamp, and nothing else', () {
      // An account that receives complaints about its own product must not be
      // able to edit what those complaints say. Only `handledAt` may move.
      expect(rules, contains("hasOnly(['handledAt'])"));
    });

    test('and a complaint can never be deleted', () {
      for (final collection in const ['note_reports', 'data_corrections']) {
        expect(block(collection), contains('allow delete: if false'),
            reason: collection);
      }
    });
  });

  group('how long somebody has been waiting', () {
    InboxItem item(DateTime? at) => InboxItem(
          id: 'x',
          kind: InboxKind.correction,
          createdAt: at,
        );

    final now = DateTime(2026, 9, 10);

    test('counted in whole days', () {
      expect(item(DateTime(2026, 9, 10)).daysWaiting(now), 0);
      expect(item(DateTime(2026, 9, 3)).daysWaiting(now), 7);
    });

    test('urgent at seven days, not at fourteen', () {
      // Flagging only on day fourteen flags a request that is already being
      // answered late. Seven is where it stops being comfortable.
      expect(item(DateTime(2026, 9, 4)).isUrgent(now), isFalse);
      expect(item(DateTime(2026, 9, 3)).isUrgent(now), isTrue);
    });

    test('a request whose timestamp has not landed yet is not urgent', () {
      // A server timestamp is null for the moment between the local write and
      // the server's answer. Treating that as "waiting forever" would paint
      // every fresh request red.
      expect(item(null).daysWaiting(now), isNull);
      expect(item(null).isUrgent(now), isFalse);
    });
  });

  test('only unanswered requests are fetched, oldest first', () {
    // Oldest first because the oldest is the one closest to breaking the
    // fourteen days, and the query is bounded because this runs on a plan with
    // 50,000 reads a day for the whole app.
    final repo =
        File('lib/data/repositories/operator_inbox_repository.dart')
            .readAsStringSync();
    expect(repo, contains("where('handledAt', isNull: true)"));
    expect(repo, contains("orderBy('createdAt')"));
    expect(repo, contains('.limit('));
  });

  test('nobody but the operator opens the streams at all', () {
    // Not merely hidden: for everyone else the query is never issued, so no
    // read is spent and no rule is tested.
    final provider =
        File('lib/presentation/providers/operator_inbox_provider.dart')
            .readAsStringSync();
    expect(provider, contains('if (!ref.watch(isOperatorProvider))'));
    expect(provider, contains('emailVerified'),
        reason: 'the UI check matches what the rules check');
  });

  test('the card names the commitment rather than nagging', () {
    final card =
        File('lib/presentation/widgets/operator_inbox_card.dart')
            .readAsStringSync();
    expect(card, contains('14 יום'));
  });
}
