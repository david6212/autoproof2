// The desktop layout can't be eyeballed from here — Flutter paints to a
// canvas, so a screenshot tool sees nothing it can read. These tests assert
// the two things the layout work actually promises: that a wide window gets a
// centred column instead of a stretched one, and that a phone gets back
// exactly the tree it had before.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:otov/presentation/widgets/car_card_widget.dart';
import 'package:otov/presentation/widgets/responsive_frame.dart';

/// Pumps [child] into a window [width] logical pixels across.
Future<void> _pumpAt(WidgetTester tester, double width, Widget child) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(child);
  await tester.pump();
}

void main() {
  group('ResponsiveFrame', () {
    const appKey = Key('app');
    const app = SizedBox.expand(key: appKey);

    testWidgets('leaves a phone-width window untouched', (tester) async {
      await _pumpAt(
        tester,
        400,
        const Directionality(
          textDirection: TextDirection.rtl,
          child: ResponsiveFrame(child: app),
        ),
      );

      expect(tester.getSize(find.byKey(appKey)).width, 400);
    });

    testWidgets('caps a desktop window at the app width', (tester) async {
      await _pumpAt(
        tester,
        1440,
        const Directionality(
          textDirection: TextDirection.rtl,
          child: ResponsiveFrame(child: app),
        ),
      );

      expect(tester.getSize(find.byKey(appKey)).width,
          AppBreakpoint.appMaxWidth);
    });

    testWidgets('still fills the full height when centred', (tester) async {
      await _pumpAt(
        tester,
        1440,
        const Directionality(
          textDirection: TextDirection.rtl,
          child: ResponsiveFrame(child: app),
        ),
      );

      expect(tester.getSize(find.byKey(appKey)).height, 900);
    });

    testWidgets('centres the app column', (tester) async {
      await _pumpAt(
        tester,
        1440,
        const Directionality(
          textDirection: TextDirection.rtl,
          child: ResponsiveFrame(child: app),
        ),
      );

      final left = tester.getTopLeft(find.byKey(appKey)).dx;
      final right = tester.getTopRight(find.byKey(appKey)).dx;
      // Equal gutters either side, allowing for the 1px edge on each side.
      expect(left, closeTo(1440 - right, 1.0));
    });
  });

  group('CarListView', () {
    Widget listView() => const MaterialApp(
          home: Scaffold(
            body: CarListView(cars: [], cardBuilder: _noCard),
          ),
        );

    testWidgets('is a single column on a phone', (tester) async {
      await _pumpAt(tester, 400, listView());

      expect(find.byType(SliverList), findsOneWidget);
      expect(find.byType(SliverGrid), findsNothing);
    });

    testWidgets('becomes a grid when there is room for two', (tester) async {
      await _pumpAt(tester, AppBreakpoint.appMaxWidth, listView());

      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.byType(SliverList), findsNothing);
    });
  });
}

Widget _noCard(car) => const SizedBox.shrink();
