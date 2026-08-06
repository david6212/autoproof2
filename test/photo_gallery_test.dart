// The gallery is the one part of the car page nobody can check by looking:
// Flutter paints to a canvas, so there is no screenshot to read. These tests
// measure the things the design pass actually promises — that the hero grows
// with the window instead of staying a 900x280 letterbox, that the chrome over
// a photo has enough contrast to survive a white car, that the tap targets are
// finger-sized, and that the fullscreen viewer counts and closes correctly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:otov/core/theme/app_palette.dart';
import 'package:otov/data/models/car_model.dart';
import 'package:otov/presentation/widgets/car_photo_gallery.dart';
import 'package:otov/presentation/widgets/photo_viewer.dart';
import 'package:otov/presentation/widgets/seller_type_badge.dart';

CarModel car({List<String> photos = const []}) => CarModel(
      id: 'c1',
      // Deliberately not a plausible plate: a real one has no place in a
      // fixture that could be copied into a demo.
      plate: '00000000',
      make: 'טויוטה',
      model: 'קורולה',
      year: 2019,
      price: 80000,
      km: 90000,
      hand: 2,
      area: 'מרכז',
      sellerId: 's1',
      status: CarStatus.active,
      photos: photos,
      reasonForSelling: '',
      createdAt: DateTime(2024),
    );

List<String> urls(int n) =>
    List.generate(n, (i) => 'https://example.invalid/$i.jpg');

Future<void> pumpAt(
  WidgetTester tester,
  Size size,
  Widget child, {
  AppPalette palette = AppPalette.light,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('he'),
      theme: ThemeData(extensions: [palette]),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    ),
  );
  // Never pumpAndSettle here: the loading placeholder shimmers forever by
  // design, so settling would time out rather than tell us anything.
  await tester.pump();
}

double contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  final (hi, lo) = x > y ? (x, y) : (y, x);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('gallery height', () {
    testWidgets('grows with a phone-width window', (tester) async {
      await pumpAt(tester, const Size(400, 900), CarPhotoGallery(car: car()));

      // 400 * 0.72, inside both bounds.
      expect(tester.getSize(find.byType(CarPhotoGallery)).height, 288);
    });

    testWidgets('is taller inside the desktop frame, not the same 280',
        (tester) async {
      // The desktop frame caps the app column at 900; that is the width the
      // gallery actually gets on a wide window.
      await pumpAt(tester, const Size(900, 1000), CarPhotoGallery(car: car()));

      final wide = tester.getSize(find.byType(CarPhotoGallery)).height;
      expect(wide, 360, reason: 'capped so the price stays above the fold');
      expect(wide, greaterThan(288));
    });

    testWidgets('never shrinks below a usable hero on a small phone',
        (tester) async {
      await pumpAt(tester, const Size(300, 800), CarPhotoGallery(car: car()));

      expect(tester.getSize(find.byType(CarPhotoGallery)).height, 240);
    });

    testWidgets('gives up height rather than fill a short landscape window',
        (tester) async {
      await pumpAt(tester, const Size(800, 400), CarPhotoGallery(car: car()));

      // Half the window, not 0.72 of the width (576).
      expect(tester.getSize(find.byType(CarPhotoGallery)).height, 200);
    });
  });

  group('gallery chrome', () {
    testWidgets('empty listing says so instead of showing a bare icon',
        (tester) async {
      await pumpAt(tester, const Size(400, 900), CarPhotoGallery(car: car()));

      expect(find.text('לא צורפו תמונות למודעה'), findsOneWidget);
      // Nothing to open, so no fullscreen affordance is offered.
      expect(find.byIcon(Icons.fullscreen), findsNothing);
    });

    testWidgets('offers a fullscreen affordance with the photo count',
        (tester) async {
      await pumpAt(
        tester,
        const Size(400, 900),
        CarPhotoGallery(car: car(photos: urls(4))),
      );

      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
      expect(find.text('4 תמונות'), findsOneWidget);
    });

    testWidgets('a single photo is counted in the singular', (tester) async {
      await pumpAt(
        tester,
        const Size(400, 900),
        CarPhotoGallery(car: car(photos: urls(1))),
      );

      expect(find.text('תמונה אחת'), findsOneWidget);
      // One photo has no position to indicate.
      expect(find.text('1/1'), findsNothing);
    });

    testWidgets('shows dots while they are countable', (tester) async {
      await pumpAt(
        tester,
        const Size(400, 900),
        CarPhotoGallery(car: car(photos: urls(5))),
      );

      expect(find.byType(AnimatedContainer), findsNWidgets(5));
      expect(find.textContaining('/5'), findsNothing);
    });

    testWidgets('switches to a number once dots would be mush',
        (tester) async {
      await pumpAt(
        tester,
        const Size(400, 900),
        CarPhotoGallery(car: car(photos: urls(12))),
      );

      expect(find.byType(AnimatedContainer), findsNothing);
      expect(find.text('1/12'), findsOneWidget);
    });

    testWidgets('the dots never run under the seller badge', (tester) async {
      // The narrowest phone the app supports, with a full house of dots. This
      // is the case that overlapped when the two were independently placed.
      await pumpAt(
        tester,
        const Size(320, 800),
        CarPhotoGallery(car: car(photos: urls(CarPhotoGallery.maxDots))),
      );

      final badge = tester.getRect(find.byType(SellerTypeBadge));
      final dots = tester.getRect(find.ancestor(
        of: find.byType(AnimatedContainer).first,
        matching: find.byType(PhotoChip),
      ));

      // RTL: the badge sits at the start edge, on the right.
      expect(dots.right, lessThanOrEqualTo(badge.left));
      expect(dots.width, greaterThan(0));
    });

    testWidgets('back and share clear the 48px tap target', (tester) async {
      await pumpAt(
        tester,
        const Size(400, 900),
        CarPhotoGallery(car: car(photos: urls(3))),
      );

      // The CircleAvatar these replaced was 40x40 — under the guideline on
      // both platforms, over a photo, at the top of the app's busiest screen.
      expect(tester.getSize(find.byKey(CarPhotoGallery.backKey)),
          const Size(48, 48));
      expect(tester.getSize(find.byKey(CarPhotoGallery.shareKey)),
          const Size(48, 48));

      // The fullscreen pill is shorter than a finger, so its box is the target.
      expect(tester.getSize(find.byKey(CarPhotoGallery.expandKey)).height,
          greaterThanOrEqualTo(48));
    });
  });

  group('opening the viewer', () {
    // Never pumpAndSettle in this group: the gallery stays alive under the
    // pushed route and its loading placeholder shimmers on a repeating
    // controller, which settling would wait on forever.
    Future<void> openAnd(WidgetTester tester, Finder target) async {
      await pumpAt(
        tester,
        const Size(400, 900),
        CarPhotoGallery(car: car(photos: urls(3))),
      );
      await tester.tap(target);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('the fullscreen button opens it', (tester) async {
      await openAnd(tester, find.byKey(CarPhotoGallery.expandKey));
      expect(find.byType(PhotoViewer), findsOneWidget);
    });

    testWidgets('so does tapping the photo', (tester) async {
      await openAnd(tester, find.byType(PageView));
      expect(find.byType(PhotoViewer), findsOneWidget);
    });
  });

  group('dark theme', () {
    testWidgets('the empty state uses the ink that belongs on tealLight',
        (tester) async {
      await pumpAt(
        tester,
        const Size(400, 900),
        CarPhotoGallery(car: car()),
        palette: AppPalette.dark,
      );

      // The pairing, not the pixel: whatever tealLight becomes in dark, the
      // label on it has to be the tealText that was designed against it.
      final label = tester.widget<Text>(find.text('לא צורפו תמונות למודעה'));
      expect(label.style!.color, AppPalette.dark.tealText);
      expect(AppPalette.dark.tealText, isNot(AppPalette.light.tealText));
    });

    testWidgets('over-photo chrome stays white in both themes',
        (tester) async {
      for (final palette in [AppPalette.light, AppPalette.dark]) {
        await pumpAt(
          tester,
          const Size(400, 900),
          CarPhotoGallery(car: car(photos: urls(12))),
          palette: palette,
        );

        final counter = tester.widget<DefaultTextStyle>(
          find
              .ancestor(
                of: find.text('1/12'),
                matching: find.byType(DefaultTextStyle),
              )
              .first,
        );
        // onBrand, not surface — the scrim under it is dark either way.
        expect(counter.style.color, palette.onBrand);
      }
    });
  });

  group('over-photo contrast', () {
    test('chrome survives the worst case: a photo of a white car', () {
      // A photo is not a themed surface. The chip is a fixed black scrim, so
      // the worst background it can ever sit on is pure white showing through.
      final worstCase = Color.alphaBlend(
        Colors.black.withValues(alpha: PhotoChip.scrimAlpha),
        Colors.white,
      );

      expect(contrast(Colors.white, worstCase), greaterThan(4.5),
          reason: 'the counter and the hint are small text');
    });

    test('the same chip is still readable over a black photo', () {
      expect(contrast(Colors.white, Colors.black), greaterThan(4.5));
    });
  });

  group('fullscreen viewer', () {
    testWidgets('counts photos and offers a way out', (tester) async {
      await pumpAt(
        tester,
        const Size(400, 900),
        PhotoViewer(photos: urls(3), initialIndex: 1),
      );

      expect(find.text('2/3'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsWidgets);
    });

    testWidgets('fills the window instead of collapsing onto its own chrome',
        (tester) async {
      await pumpAt(
        tester,
        const Size(400, 900),
        PhotoViewer(photos: urls(2)),
      );

      // A Scaffold gives its body a loose height, so a Stack sized by its
      // children shrank to the 64px button row and showed a sliver of photo.
      expect(
        tester.getSize(find.descendant(
          of: find.byType(PhotoViewer),
          matching: find.byType(PageView),
        )),
        const Size(400, 900),
      );
    });

    testWidgets('says how to zoom and where the photos came from',
        (tester) async {
      await pumpAt(
        tester,
        const Size(400, 900),
        PhotoViewer(photos: urls(2)),
      );

      expect(find.text(PhotoViewer.zoomHint), findsOneWidget);
      // The claims rule cuts both ways: this states what we did NOT do.
      expect(find.text(PhotoViewer.sourceNote), findsOneWidget);
    });

    testWidgets('hands the index it closed on back to the carousel',
        (tester) async {
      int? closedOn;

      await pumpAt(
        tester,
        const Size(400, 900),
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              closedOn = await showPhotoViewer(
                context,
                photos: urls(4),
                initialIndex: 2,
              );
            },
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      // Settle the route transition: until it finishes the viewer is still
      // behind an IgnorePointer and the close button cannot be tapped.
      await tester.pumpAndSettle();

      expect(find.text('3/4'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(closedOn, 2);
    });
  });
}
