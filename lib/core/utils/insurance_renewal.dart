import '../../data/models/expense.dart';
import '../../data/models/service_record.dart';

/// When the owner's insurance probably runs out, and why the app has to ask.
///
/// **The registry does not carry it.** A vehicle licence expiry is a public
/// fact and the app reads it; an insurance policy is a private contract between
/// the owner and an insurer, and nothing in any government dataset knows when
/// it ends. So unlike the test reminder, this one cannot be created from data —
/// it can only be asked for.
///
/// That is also why nothing here writes a reminder by itself. The rule the
/// reminders were built on is that only [ReminderType.test] is automatic,
/// because it is the only date that is a fact. A date this class produces is a
/// **guess put in front of the owner to confirm or correct**, and it is
/// labelled as one on screen.
///
/// ## Why guess at all
///
/// Because the alternative is an empty date picker, and an empty date picker on
/// a screen somebody opened for another reason gets closed. Israeli motor
/// policies run twelve months; an owner who logged last year's premium has
/// already told us, without meaning to, roughly when this year's is due.
class InsuranceRenewal {
  InsuranceRenewal._();

  /// How far ahead an insurance reminder should start showing.
  ///
  /// Longer than the 21 days the other reminders use, deliberately. A test is
  /// an appointment you book; insurance renewal is a market you shop, and the
  /// whole value of knowing early is having time to compare before the policy
  /// auto-renews at whatever the insurer decided. Three weeks is enough notice
  /// to comply and not enough to negotiate.
  static const leadDays = 45;

  /// How long an Israeli motor policy usually runs.
  static const term = Duration(days: 365);

  /// A date to offer the owner, from the last insurance payment they recorded,
  /// or null when there is nothing to base one on.
  ///
  /// Returns null rather than a stale date when the guess would already be in
  /// the past: offering "renew by a date three months ago" teaches the reader
  /// that the suggestion is not to be trusted, which costs more than the empty
  /// field it replaced.
  static DateTime? suggest({
    required List<ServiceRecord> services,
    required List<Expense> expenses,
    required DateTime now,
  }) {
    final dates = <DateTime>[
      for (final s in services)
        if (s.type == ServiceType.insurance) s.date,
      for (final e in expenses)
        if (e.type == ExpenseType.insurance) e.date,
    ];
    if (dates.isEmpty) return null;

    dates.sort();
    final guess = dates.last.add(term);
    return guess.isAfter(now) ? guess : null;
  }
}
