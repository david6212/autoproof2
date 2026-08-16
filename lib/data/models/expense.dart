enum ExpenseType { fuel, cleaning, parking, insurance, fees, tolls, other }

extension ExpenseTypeX on ExpenseType {
  String get label => switch (this) {
        ExpenseType.fuel => 'תדלוק',
        ExpenseType.cleaning => 'ניקיון',
        ExpenseType.parking => 'חניה',
        ExpenseType.insurance => 'ביטוח',
        ExpenseType.fees => 'אגרות',
        ExpenseType.tolls => 'כבישי אגרה',
        ExpenseType.other => 'אחר',
      };
}

/// A running cost of owning the car — fuel, a wash, parking, the insurance
/// premium.
///
/// **Deliberately separate from [ServiceRecord], and deliberately editable.**
/// The two are different things pretending to be similar:
///
/// A service record is evidence for the next buyer, so it is append-only and
/// public once the car is listed. An expense is the owner's own budget. Nobody
/// buying a car needs to know what its previous owner spent on petrol in
/// March, and locking a weekly refuel entry forever would mean a single typo
/// lives in the timeline for the life of the car. So expenses can be edited
/// and deleted freely, and they are never shown to a buyer — not while the car
/// is listed, and not after it is sold.
class Expense {
  final String id;
  final ExpenseType type;
  final String title;
  final DateTime date;
  final int amount; // shekels

  /// Litres, on a refuel. With [km] this gives real consumption, which is the
  /// one number a driver actually wants out of a fuel log.
  final double? litres;

  /// Odometer at the time. Optional — asking for it on every wash would make
  /// logging a chore, and the whole feature dies if logging is a chore.
  final int? km;

  final String? notes;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.type,
    this.title = '',
    required this.date,
    required this.amount,
    this.litres,
    this.km,
    this.notes,
    required this.createdAt,
  });

  /// Shekels per litre on this refuel, when both numbers are there.
  double? get pricePerLitre {
    final l = litres;
    if (l == null || l <= 0 || type != ExpenseType.fuel) return null;
    return amount / l;
  }

  String get displayTitle => title.trim().isNotEmpty ? title.trim() : type.label;

  factory Expense.fromFirestore(Map<String, dynamic> data, String id) {
    return Expense(
      id: id,
      type: ExpenseType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => ExpenseType.other,
      ),
      title: data['title'] ?? '',
      date: (data['date'] as dynamic)?.toDate() ?? DateTime.now(),
      amount: (data['amount'] ?? 0) is int
          ? (data['amount'] ?? 0)
          : int.tryParse('${data['amount']}') ?? 0,
      litres: (data['litres'] as num?)?.toDouble(),
      km: data['km'] == null
          ? null
          : (data['km'] is int ? data['km'] : int.tryParse('${data['km']}')),
      notes: data['notes'],
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type.name,
        'title': title,
        'date': date,
        'amount': amount,
        'litres': litres,
        'km': km,
        'notes': notes,
        'createdAt': createdAt,
      };

  Expense copyWith({
    ExpenseType? type,
    String? title,
    DateTime? date,
    int? amount,
    double? litres,
    int? km,
    String? notes,
  }) =>
      Expense(
        id: id,
        type: type ?? this.type,
        title: title ?? this.title,
        date: date ?? this.date,
        amount: amount ?? this.amount,
        litres: litres ?? this.litres,
        km: km ?? this.km,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}

/// A month's spending, grouped for the expenses tab.
class ExpenseMonth {
  final int year;
  final int month;
  final int total;
  final Map<ExpenseType, int> byType;

  const ExpenseMonth({
    required this.year,
    required this.month,
    required this.total,
    required this.byType,
  });

  /// Groups expenses by calendar month, newest month first.
  static List<ExpenseMonth> group(List<Expense> expenses) {
    final buckets = <String, List<Expense>>{};
    for (final e in expenses) {
      buckets.putIfAbsent('${e.date.year}-${e.date.month}', () => []).add(e);
    }
    final months = <ExpenseMonth>[];
    for (final entry in buckets.entries) {
      final list = entry.value;
      final byType = <ExpenseType, int>{};
      var total = 0;
      for (final e in list) {
        byType[e.type] = (byType[e.type] ?? 0) + e.amount;
        total += e.amount;
      }
      months.add(ExpenseMonth(
        year: list.first.date.year,
        month: list.first.date.month,
        total: total,
        byType: byType,
      ));
    }
    months.sort((a, b) => b.year != a.year
        ? b.year.compareTo(a.year)
        : b.month.compareTo(a.month));
    return months;
  }

  /// Total spent on one type across a list — "כמה יצא לי החודש על תדלוק".
  static int totalOf(List<Expense> expenses, ExpenseType type) {
    var sum = 0;
    for (final e in expenses) {
      if (e.type == type) sum += e.amount;
    }
    return sum;
  }
}
