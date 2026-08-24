import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/data/models/vehicle_document.dart';
import 'package:bonnetcheck/presentation/widgets/document_list.dart';

/// Documents are the one place in the passport where a user can publish their
/// own personal data by accident. A vehicle licence carries an ID number and a
/// home address; sharing it is a decision, never a default. These pin that.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              width: 390,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      );

  VehicleDocument doc({
    DocumentType type = DocumentType.inspectionReport,
    bool shared = false,
  }) =>
      VehicleDocument(
        id: 'd1',
        type: type,
        title: type.label,
        fileUrl: 'https://example.test/a.jpg',
        storagePath: 'vehicles/u1/v1/documents/d1.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 120000,
        isSharedWithBuyers: shared,
        uploadedByOwnerId: 'u1',
        uploadedAt: DateTime(2026, 3, 1),
      );

  testWidgets('a document is private until the owner shares it',
      (tester) async {
    await tester.pumpWidget(host(
      DocumentList(documents: [doc()], onToggleShare: (_, __) {}),
    ));

    expect(find.text('פרטי'), findsOneWidget);
    expect(find.text('מוצג לקונים'), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('sharing a licence asks first and does nothing until confirmed',
      (tester) async {
    bool? result;
    await tester.pumpWidget(host(
      DocumentList(
        documents: [doc(type: DocumentType.licence)],
        onToggleShare: (_, shared) => result = shared,
      ),
    ));

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('להציג את המסמך לקונים?'), findsOneWidget);
    expect(result, isNull, reason: 'nothing may be shared before confirming');

    // Turning the switch back off hides the document but cannot revoke a link
    // somebody already copied — a Storage download URL carries its own token.
    // The moment of the decision is when that has to be said.
    expect(find.textContaining('רק מחיקת הקובץ מבטלת גישה'),
        findsOneWidget);

    await tester.tap(find.text('ביטול'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('confirming the warning is what actually shares it',
      (tester) async {
    bool? result;
    await tester.pumpWidget(host(
      DocumentList(
        documents: [doc(type: DocumentType.insurance)],
        onToggleShare: (_, shared) => result = shared,
      ),
    ));

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('הצג בכל זאת'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('a report with no personal data shares without a warning',
      (tester) async {
    // Warning on every document would train people to tap straight through it,
    // which is worse than not warning at all.
    bool? result;
    await tester.pumpWidget(host(
      DocumentList(
        documents: [doc(type: DocumentType.inspectionReport)],
        onToggleShare: (_, shared) => result = shared,
      ),
    ));

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('להציג את המסמך לקונים?'), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('unsharing never asks — taking something back is always safe',
      (tester) async {
    bool? result;
    await tester.pumpWidget(host(
      DocumentList(
        documents: [doc(type: DocumentType.licence, shared: true)],
        onToggleShare: (_, shared) => result = shared,
      ),
    ));

    expect(find.text('מוצג לקונים'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('להציג את המסמך לקונים?'), findsNothing);
    expect(result, isFalse);
  });

  testWidgets('deleting says plainly that it is the only real revocation',
      (tester) async {
    // A Storage download URL keeps working after unsharing, so the dialog has
    // to be honest about what deletion is for.
    await tester.pumpWidget(host(
      DocumentList(documents: [doc()], onDelete: (_) {}),
    ));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('הדרך היחידה לבטל גישה'), findsOneWidget);
  });

  testWidgets('the buyer view can open a document but not change anything',
      (tester) async {
    await tester.pumpWidget(host(
      DocumentList(
        documents: [doc(shared: true)],
        readOnly: true,
        onToggleShare: (_, __) {},
        onDelete: (_) {},
      ),
    ));

    expect(find.byType(Switch), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('פתח'), findsOneWidget);
  });
}
