enum ReminderType { test, insurance, timingBelt, serviceKm, custom }

extension ReminderTypeX on ReminderType {
  String get label => switch (this) {
        ReminderType.test => 'טסט',
        ReminderType.insurance => 'ביטוח',
        ReminderType.timingBelt => 'רצועת תזמון',
        ReminderType.serviceKm => 'טיפול לפי ק"מ',
        ReminderType.custom => 'תזכורת',
      };
}

/// Where a reminder came from.
enum ReminderSource {
  auto, // derived from official data (test expiry)
  manual, // the owner entered it
}

/// A due date or due mileage the owner wants to be reminded about.
///
/// Only [ReminderType.test] is created automatically, because the test expiry
/// is the one date that comes from the vehicle registry and is therefore a
/// fact. Everything else is entered by the owner. We deliberately do not ship
/// a table of timing-belt intervals per model: we have no licensed source for
/// it, and telling someone their belt is due — on our own authority — would be
/// a claim about the condition of their car, which is exactly what the app
/// does not do.
class VehicleReminder {
  final String id;
  final ReminderType type;
  final String title;
  final DateTime? dueDate;
  final int? dueKm;
  final bool isDone;
  final ReminderSource source;
  final DateTime createdAt;

  const VehicleReminder({
    required this.id,
    required this.type,
    required this.title,
    this.dueDate,
    this.dueKm,
    this.isDone = false,
    this.source = ReminderSource.manual,
    required this.createdAt,
  });

  /// Days until due — negative once overdue. Null when this is a mileage
  /// reminder with no date.
  int? get daysUntilDue {
    final due = dueDate;
    if (due == null) return null;
    final today = DateTime.now();
    final d = DateTime(due.year, due.month, due.day);
    final t = DateTime(today.year, today.month, today.day);
    return d.difference(t).inDays;
  }

  bool get isOverdue => !isDone && (daysUntilDue ?? 1) < 0;

  /// Whether this should surface in the garage banner: due within three weeks,
  /// or already overdue.
  bool get isDueSoon {
    if (isDone) return false;
    final days = daysUntilDue;
    return days != null && days <= 21;
  }

  factory VehicleReminder.fromFirestore(Map<String, dynamic> data, String id) {
    return VehicleReminder(
      id: id,
      type: ReminderType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => ReminderType.custom,
      ),
      title: data['title'] ?? '',
      dueDate: (data['dueDate'] as dynamic)?.toDate(),
      dueKm: data['dueKm'] == null
          ? null
          : (data['dueKm'] is int
              ? data['dueKm']
              : int.tryParse('${data['dueKm']}')),
      isDone: data['isDone'] == true,
      source: ReminderSource.values.firstWhere(
        (s) => s.name == data['source'],
        orElse: () => ReminderSource.manual,
      ),
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type.name,
        'title': title,
        'dueDate': dueDate,
        'dueKm': dueKm,
        'isDone': isDone,
        'source': source.name,
        'createdAt': createdAt,
      };
}
