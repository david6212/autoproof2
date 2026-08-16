import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense.dart';

/// The owner's private running-cost ledger for a vehicle.
///
/// Unlike [ServiceRepository] this one has a full set of methods, on purpose.
/// Expenses are the owner's own budget, not evidence for anyone else, so
/// fixing a mistyped refuel should be one tap and not a correction record.
/// Nothing here is ever exposed to a buyer.
class ExpenseRepository {
  ExpenseRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _expenses(String vehicleId) =>
      _db.collection('vehicles').doc(vehicleId).collection('expenses');

  /// The ledger, newest first.
  Stream<List<Expense>> watchExpenses(String vehicleId) =>
      _expenses(vehicleId).snapshots().map((snap) {
        final list = [
          for (final d in snap.docs) Expense.fromFirestore(d.data(), d.id),
        ];
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      });

  Future<String> addExpense(String vehicleId, Expense expense) async {
    final ref = await _expenses(vehicleId).add(expense.toFirestore());
    return ref.id;
  }

  Future<void> updateExpense(String vehicleId, Expense expense) =>
      _expenses(vehicleId).doc(expense.id).update(expense.toFirestore());

  Future<void> deleteExpense(String vehicleId, String expenseId) =>
      _expenses(vehicleId).doc(expenseId).delete();

  /// Spending in a given calendar month — what "כמה יצא לי החודש על תדלוק"
  /// actually asks for.
  static List<Expense> inMonth(List<Expense> all, int year, int month) => [
        for (final e in all)
          if (e.date.year == year && e.date.month == month) e,
      ];

  /// Litres per 100 km across the refuels that recorded an odometer reading.
  ///
  /// Returns null below two such refuels: consumption is a difference between
  /// two fill-ups, so one is not a measurement. Partial fills make this an
  /// estimate rather than a number to argue with, which is why the UI labels
  /// it "ממוצע משוער".
  static double? consumptionPer100Km(List<Expense> all) {
    final fills = [
      for (final e in all)
        if (e.type == ExpenseType.fuel && e.km != null && e.litres != null) e,
    ]..sort((a, b) => a.km!.compareTo(b.km!));
    if (fills.length < 2) return null;

    final distance = fills.last.km! - fills.first.km!;
    if (distance <= 0) return null;

    // The first fill-up's litres went into the tank before the distance was
    // driven, so they are not part of what the distance consumed.
    var litres = 0.0;
    for (var i = 1; i < fills.length; i++) {
      litres += fills[i].litres!;
    }
    if (litres <= 0) return null;

    return litres / distance * 100;
  }
}
