import '../../data/models/expense.dart';
import '../../data/models/gov_data_model.dart';
import '../../data/models/service_record.dart';
import '../utils/date_formatter.dart';

/// Everything the assistant is allowed to answer from.
///
/// Deliberately a plain value object with no repository and no network: if a
/// fact is not in here, the assistant does not know it, and the honest answer
/// is to say so rather than to reach for something.
class AssistantContext {
  const AssistantContext({
    this.gov,
    this.services = const [],
    this.expenses = const [],
    this.openRecalls = 0,
    this.govReachable = true,
    required this.now,
  });

  /// The registry's record, or null if it was never fetched or failed.
  final GovData? gov;

  final List<ServiceRecord> services;
  final List<Expense> expenses;
  final int openRecalls;

  /// Whether the registry answered at all. **Not the same as zero findings** —
  /// "we could not check" and "we checked and found nothing" are different
  /// answers and the assistant must never collapse them.
  final bool govReachable;

  /// Injected so every answer involving a date is testable.
  final DateTime now;
}

/// One answer, with the thing it came from attached.
class AssistantAnswer {
  const AssistantAnswer({required this.text, required this.source});

  final String text;

  /// Where the fact came from, shown to the reader. An assistant that states
  /// facts without saying where they came from is asking to be trusted, and
  /// this app does not ask for trust — it shows its work.
  final String source;
}

/// Answers questions about the reader's own car, on the device, for nothing.
///
/// **A keyword table, not a language model.** That is a feature: it costs no
/// money, needs no network, cannot be prompt-injected, cannot hallucinate a
/// service record, and behaves identically every time. Roughly every question
/// people actually ask about their own car is one of a dozen, and a dozen
/// intents answer them from data the app already holds.
///
/// [answer] returns **null** when nothing matches, so a caller can fall
/// through to something else without this class having to know what that is.
/// Guessing at an unrecognised question is the one behaviour that would make it
/// worse than nothing.
///
/// ## What it will never say
///
/// It reports records. It does not appraise the car. There is no path here that
/// produces "the car is fine", "worth buying", or a score — the same rule the
/// rest of the app follows, applied to the one surface where it would be
/// easiest to break, because an answer phrased as advice reads as advice.
class CarAssistant {
  CarAssistant._();

  static const sourceRegistry = 'לפי מרשם הרכב';
  static const sourceRecords = 'לפי רשומות הטיפול שלכם';
  static const sourceExpenses = 'לפי ההוצאות שרשמתם';

  static AssistantAnswer? answer(String question, AssistantContext ctx) {
    final q = _normalise(question);
    if (q.isEmpty) return null;

    for (final intent in _intents) {
      if (!intent.matches(q)) continue;
      final a = intent.answer(q, ctx);
      // An intent that matched but has no data to answer with falls through to
      // the next one rather than returning a confident nothing.
      if (a != null) return a;
    }
    return null;
  }

  /// Lower-cases, drops punctuation, and folds Hebrew final letters so that
  /// "צמיגים" and "צמיג" reach the same keyword. Crude, and enough: this is
  /// keyword matching, not morphology.
  static String _normalise(String raw) {
    const finals = {'ם': 'מ', 'ן': 'נ', 'ץ': 'צ', 'ף': 'פ', 'ך': 'כ'};
    final buffer = StringBuffer();
    for (final ch in raw.trim().toLowerCase().split('')) {
      if (RegExp(r'[^\w֐-׿ ]').hasMatch(ch)) {
        buffer.write(' ');
      } else {
        buffer.write(finals[ch] ?? ch);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const _intents = <_Intent>[
    _Intent(_test, ['טסט', 'רישיו', 'תוקפ', 'מבחנ רישוי']),
    _Intent(_recall, ['ריקול', 'קריאת שירות', 'קריאות שירות', 'החזר']),
    _Intent(_spent, ['הוצאתי', 'הוצאות', 'עלה לי', 'כמה שילמתי', 'עלות']),
    _Intent(_lastService, [
      'צמיג', 'בלמ', 'רצועת תזמונ', 'תזמונ', 'טיפול', 'החלפתי', 'ביטוח',
    ]),
    _Intent(_mileage, ['קילומטר', 'ק"מ', 'קמ', 'מד אוצ']),
    _Intent(_carFacts, ['איזה רכב', 'דגמ', 'שנת יצור', 'צבע', 'סוג דלק']),
  ];

  // ---------------------------------------------------------------- intents --

  static AssistantAnswer? _test(String q, AssistantContext ctx) {
    if (!ctx.govReachable) {
      return const AssistantAnswer(
        text: 'לא הצלחנו להגיע למרשם הרכב כרגע, אז אין לנו תשובה על תוקף הרישיון.',
        source: 'אין נתונים',
      );
    }
    final expiry = ctx.gov?.licenseExpiry;
    if (expiry == null) return null;

    final days = expiry.difference(ctx.now).inDays;
    final date = DateFormatter.format(expiry);
    if (days < 0) {
      return AssistantAnswer(
        text: 'תוקף הרישיון פג ב-$date, לפני ${-days} ימים.',
        source: sourceRegistry,
      );
    }
    return AssistantAnswer(
      text: days == 0
          ? 'תוקף הרישיון נגמר היום, $date.'
          : 'תוקף הרישיון עד $date — בעוד $days ימים.',
      source: sourceRegistry,
    );
  }

  static AssistantAnswer? _recall(String q, AssistantContext ctx) {
    if (!ctx.govReachable) {
      return const AssistantAnswer(
        text: 'מאגר קריאות השירות לא היה זמין, כך שלא בדקנו. '
            'זה לא אומר שאין.',
        source: 'אין נתונים',
      );
    }
    if (ctx.openRecalls == 0) {
      // Careful wording: what we can say is that the dataset listed none, not
      // that the car has none and certainly not that it is sound.
      return const AssistantAnswer(
        text: 'במאגר קריאות השירות לא רשומות קריאות פתוחות על הרכב.',
        source: sourceRegistry,
      );
    }
    return AssistantAnswer(
      text: ctx.openRecalls == 1
          ? 'רשומה קריאת שירות פתוחה אחת. התיקון מבוצע ללא עלות בסוכנות מורשית.'
          : 'רשומות ${ctx.openRecalls} קריאות שירות פתוחות. '
              'התיקון מבוצע ללא עלות בסוכנות מורשית.',
      source: sourceRegistry,
    );
  }

  static AssistantAnswer? _spent(String q, AssistantContext ctx) {
    final thisYear = q.contains('השנה');
    bool inRange(DateTime d) => !thisYear || d.year == ctx.now.year;

    final services = ctx.services.where((s) => inRange(s.date));
    final expenses = ctx.expenses.where((e) => inRange(e.date));
    final total = services.fold<int>(0, (sum, s) => sum + s.cost) +
        expenses.fold<int>(0, (sum, e) => sum + e.amount);
    final count = services.length + expenses.length;

    if (count == 0) {
      return AssistantAnswer(
        text: thisYear
            ? 'לא רשומות הוצאות על הרכב השנה.'
            : 'עוד לא רשמתם הוצאות על הרכב.',
        source: sourceExpenses,
      );
    }
    return AssistantAnswer(
      text: '${thisYear ? 'השנה' : 'בסך הכול'} רשומות ${_shekels(total)} ₪ '
          'על פני $count רשומות.',
      source: sourceExpenses,
    );
  }

  static AssistantAnswer? _lastService(String q, AssistantContext ctx) {
    final type = _typeFor(q);
    final matching = ctx.services
        .where((s) => type == null || s.type == type)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (matching.isEmpty) {
      return AssistantAnswer(
        text: type == null
            ? 'עוד לא רשמתם טיפולים על הרכב.'
            : 'לא רשמתם ${type.label} על הרכב.',
        source: sourceRecords,
      );
    }
    final last = matching.first;
    final km = _shekels(last.km);
    return AssistantAnswer(
      text: '${last.title} — ${DateFormatter.format(last.date)}, '
          'ב-$km ק"מ'
          '${last.garageName == null ? '' : ', ${last.garageName}'}.',
      source: sourceRecords,
    );
  }

  static AssistantAnswer? _mileage(String q, AssistantContext ctx) {
    final readings = <int>[
      for (final s in ctx.services) s.km,
      for (final e in ctx.expenses)
        if (e.km != null) e.km!,
    ]..sort();
    if (readings.isEmpty) return null;
    return AssistantAnswer(
      text: 'הקריאה הגבוהה ביותר שרשמתם היא ${_shekels(readings.last)} ק"מ.',
      source: sourceRecords,
    );
  }

  static AssistantAnswer? _carFacts(String q, AssistantContext ctx) {
    final gov = ctx.gov;
    if (gov == null) return null;
    return AssistantAnswer(
      text: '${gov.make} ${gov.model} ${gov.year}, ${gov.color}, '
          'סוג דלק ${gov.fuelType}.',
      source: sourceRegistry,
    );
  }

  // ------------------------------------------------------------------ bits --

  static ServiceType? _typeFor(String q) {
    if (q.contains('צמיג')) return ServiceType.tires;
    if (q.contains('בלמ')) return ServiceType.brakes;
    if (q.contains('תזמונ')) return ServiceType.timingBelt;
    if (q.contains('ביטוח')) return ServiceType.insurance;
    if (q.contains('טסט')) return ServiceType.test;
    if (q.contains('טיפול')) return ServiceType.routine;
    return null;
  }

  static String _shekels(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );
}

class _Intent {
  const _Intent(this.answer, this.keywords);

  final AssistantAnswer? Function(String, AssistantContext) answer;
  final List<String> keywords;

  bool matches(String q) => keywords.any(q.contains);
}
