import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/expense.dart';
import 'package:bonnetcheck/data/models/vehicle_document.dart';
import 'package:bonnetcheck/data/repositories/expense_repository.dart';

Expense _fuel(int amount, {int? km, double? litres, DateTime? on}) => Expense(
      id: 'e',
      type: ExpenseType.fuel,
      date: on ?? DateTime(2026, 3, 10),
      amount: amount,
      km: km,
      litres: litres,
      createdAt: DateTime(2026, 3, 10),
    );

void main() {
  group('what the owner spent', () {
    test('adds up one category across a list', () {
      final all = [
        _fuel(300),
        _fuel(250),
        Expense(
          id: 'c',
          type: ExpenseType.cleaning,
          date: DateTime(2026, 3, 12),
          amount: 60,
          createdAt: DateTime(2026, 3, 12),
        ),
      ];
      expect(ExpenseMonth.totalOf(all, ExpenseType.fuel), 550);
      expect(ExpenseMonth.totalOf(all, ExpenseType.cleaning), 60);
      expect(ExpenseMonth.totalOf(all, ExpenseType.parking), 0);
    });

    test('groups by calendar month, newest first', () {
      final months = ExpenseMonth.group([
        _fuel(100, on: DateTime(2026, 1, 5)),
        _fuel(200, on: DateTime(2026, 3, 5)),
        _fuel(50, on: DateTime(2026, 3, 20)),
      ]);
      expect(months.first.month, 3);
      expect(months.first.total, 250);
      expect(months.last.month, 1);
    });

    test('a month splits its total by type', () {
      final months = ExpenseMonth.group([
        _fuel(200, on: DateTime(2026, 3, 5)),
        Expense(
          id: 'c',
          type: ExpenseType.cleaning,
          date: DateTime(2026, 3, 6),
          amount: 40,
          createdAt: DateTime(2026, 3, 6),
        ),
      ]);
      expect(months.single.byType[ExpenseType.fuel], 200);
      expect(months.single.byType[ExpenseType.cleaning], 40);
    });

    test('a month with nothing in it does not appear', () {
      expect(ExpenseMonth.group(const []), isEmpty);
    });
  });

  group('fuel consumption', () {
    // Consumption is a difference between two fill-ups, so one fill-up is not
    // a measurement — showing a number from it would be inventing data.
    test('needs two refuels that recorded an odometer', () {
      expect(
        ExpenseRepository.consumptionPer100Km([_fuel(300, km: 50000, litres: 40)]),
        isNull,
      );
    });

    test('ignores refuels with no odometer reading', () {
      final r = ExpenseRepository.consumptionPer100Km([
        _fuel(300, km: 50000, litres: 40),
        _fuel(300, litres: 40), // logged in a hurry, no km
      ]);
      expect(r, isNull);
    });

    // 500 km on the 40 litres put in AFTER the first fill-up = 8 L/100km. The
    // first fill's litres are excluded: they went in before the distance was
    // driven, so they did not fuel it.
    test('counts only the litres that fuelled the measured distance', () {
      final r = ExpenseRepository.consumptionPer100Km([
        _fuel(300, km: 50000, litres: 45),
        _fuel(280, km: 50500, litres: 40),
      ]);
      expect(r, closeTo(8.0, 0.001));
    });

    test('is unbothered by the order they were entered in', () {
      final forwards = ExpenseRepository.consumptionPer100Km([
        _fuel(300, km: 50000, litres: 45),
        _fuel(280, km: 50500, litres: 40),
      ]);
      final backwards = ExpenseRepository.consumptionPer100Km([
        _fuel(280, km: 50500, litres: 40),
        _fuel(300, km: 50000, litres: 45),
      ]);
      expect(backwards, forwards);
    });

    test('two readings at the same odometer give nothing, not infinity', () {
      final r = ExpenseRepository.consumptionPer100Km([
        _fuel(300, km: 50000, litres: 45),
        _fuel(280, km: 50000, litres: 40),
      ]);
      expect(r, isNull);
    });

    test('price per litre only applies to fuel', () {
      expect(_fuel(300, litres: 50).pricePerLitre, closeTo(6.0, 0.001));
      final wash = Expense(
        id: 'c',
        type: ExpenseType.cleaning,
        date: DateTime(2026, 3, 1),
        amount: 60,
        litres: 5,
        createdAt: DateTime(2026, 3, 1),
      );
      expect(wash.pricePerLitre, isNull);
    });
  });

  group('documents', () {
    test('nothing is shared with buyers until the owner says so', () {
      final doc = VehicleDocument(
        id: 'd',
        type: DocumentType.inspectionReport,
        title: 'דוח בדיקה',
        fileUrl: 'https://example.test/a.pdf',
        storagePath: 'vehicles/u1/v1/documents/d.pdf',
        uploadedByOwnerId: 'u1',
        uploadedAt: DateTime(2026, 3, 1),
      );
      expect(doc.isSharedWithBuyers, isFalse);
    });

    // The ones that carry an ID number or a home address get a warning before
    // they are published. The rest do not need one.
    test('knows which kinds carry personal details', () {
      expect(DocumentType.licence.carriesPersonalData, isTrue);
      expect(DocumentType.insurance.carriesPersonalData, isTrue);
      expect(DocumentType.purchaseContract.carriesPersonalData, isTrue);
      expect(DocumentType.inspectionReport.carriesPersonalData, isFalse);
      expect(DocumentType.receipt.carriesPersonalData, isFalse);
    });
  });
}
