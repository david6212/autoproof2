import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/data/models/place.dart';
import 'package:bonnetcheck/data/repositories/place_repository.dart';
import 'package:bonnetcheck/presentation/providers/place_provider.dart';
import 'package:bonnetcheck/presentation/widgets/garage/garage_name_field.dart';

/// The garage field on the service form.
///
/// The directory starts empty and will stay thin for a long time, so the two
/// behaviours that matter most are the ones for when nothing matches: the
/// field must stay usable, and a typed name must save without a link.
/// `implements` rather than `extends`: the real constructor reaches for
/// `FirebaseFirestore.instance`, and a widget test has no Firebase app.
/// `noSuchMethod` covers the members this test never calls.
class _FakePlaces implements PlaceRepository {
  _FakePlaces(this.results);

  final List<Place> results;
  int searches = 0;

  @override
  Future<List<Place>> search(String query, {int limit = 6}) async {
    searches++;
    return results;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  Place place(String name) => Place(
        id: 'p-$name',
        source: PlaceSource.community,
        category: PlaceCategory.garageMechanical,
        name: name,
        city: 'חיפה',
        createdAt: DateTime(2026, 8, 25),
      );

  Widget host(
    _FakePlaces repo,
    TextEditingController controller, {
    required ValueChanged<String?> onPlaceId,
    void Function(String)? onAdd,
  }) =>
      ProviderScope(
        overrides: [placeRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SizedBox(
                width: 390,
                child: GarageNameField(
                  controller: controller,
                  onPlaceIdSelected: onPlaceId,
                  onAddPlace: onAdd,
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('nothing is fetched until there is something to search for',
      (tester) async {
    final repo = _FakePlaces([place('מוסך כהן')]);
    final c = TextEditingController();
    await tester.pumpWidget(host(repo, c, onPlaceId: (_) {}));

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'מ');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    // One character narrows nothing and would query on every name in the
    // directory.
    expect(repo.searches, 0);
  });

  testWidgets('suggestions appear once enough is typed', (tester) async {
    final repo = _FakePlaces([place('מוסך כהן ובניו')]);
    final c = TextEditingController();
    await tester.pumpWidget(host(repo, c, onPlaceId: (_) {}));

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'כהן');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump();

    expect(find.text('מוסך כהן ובניו'), findsOneWidget);
  });

  testWidgets('picking one hands back its id and fills the name',
      (tester) async {
    String? got = 'untouched';
    final repo = _FakePlaces([place('מוסך הצפון')]);
    final c = TextEditingController();
    await tester.pumpWidget(host(repo, c, onPlaceId: (id) => got = id));

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'צפון');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('מוסך הצפון'));
    await tester.pump();

    expect(got, 'p-מוסך הצפון');
    expect(c.text, 'מוסך הצפון');
  });

  testWidgets('editing the name afterwards drops the link', (tester) async {
    // A stale id would point the record at the page of a garage it no longer
    // names.
    final ids = <String?>[];
    final repo = _FakePlaces([place('מוסך הצפון')]);
    final c = TextEditingController();
    await tester.pumpWidget(host(repo, c, onPlaceId: ids.add));

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'צפון');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('מוסך הצפון'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'מוסך הדרום');
    await tester.pump(const Duration(milliseconds: 500));

    expect(ids.last, isNull);
  });

  testWidgets('when nothing matches, the way forward is to add it',
      (tester) async {
    // Which for a while will be most of the time. A spinner that ends in an
    // empty list, with no action, reads as broken.
    String? asked;
    final repo = _FakePlaces(const []);
    final c = TextEditingController();
    await tester.pumpWidget(
        host(repo, c, onPlaceId: (_) {}, onAdd: (name) => asked = name));

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'מוסך חדש');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('להוסיף אותו לרשימה'), findsOneWidget);
    await tester.tap(find.textContaining('להוסיף אותו לרשימה'));
    await tester.pump();
    expect(asked, 'מוסך חדש');
  });

  testWidgets('without an add handler the row is absent, not dead',
      (tester) async {
    final repo = _FakePlaces(const []);
    final c = TextEditingController();
    await tester.pumpWidget(host(repo, c, onPlaceId: (_) {}));

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'מוסך חדש');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('להוסיף'), findsNothing);
  });
}
