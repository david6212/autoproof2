import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/car_model.dart';
import 'photo_viewer.dart';
import 'seller_type_badge.dart';
import 'share_listing_button.dart';
import 'skeleton.dart';

/// The hero carousel at the top of a car page.
///
/// Everything that floats over the photos — back, share, the counter, the
/// dots — sits on a fixed black scrim and paints in `onBrand`, because a photo
/// is not a themed surface and the theme's `surface` gives no guaranteed
/// contrast against one. The two exceptions are the back and share buttons,
/// which are deliberately solid `surface` circles: they are app chrome, not
/// photo chrome, and they read as the same control as everywhere else.
class CarPhotoGallery extends StatefulWidget {
  const CarPhotoGallery({super.key, required this.car});

  final CarModel car;

  /// Beyond this many photos the dots stop being countable at a glance and a
  /// numeric counter says more in less space.
  static const maxDots = 8;

  /// Named so `photo_gallery_test` can measure the tap targets. A finger-sized
  /// hit box is not visible in the tree any other way.
  static const backKey = ValueKey('gallery-back');
  static const shareKey = ValueKey('gallery-share');
  static const expandKey = ValueKey('gallery-expand');

  /// How tall the hero is at a given width.
  ///
  /// It used to be a flat 280 at every size. Inside the desktop frame that is a
  /// 900×280 letterbox — a 3.2:1 crop of a photo that was almost certainly shot
  /// at 4:3, so `BoxFit.cover` threw away most of the car. The ratio is now the
  /// same on a phone and on a desktop, with two bounds: never so short that
  /// there is nothing to look at, never so tall that the price and the registry
  /// data are pushed under the fold. The second bound is why the viewport
  /// height matters too — in landscape, half the window is already generous.
  static double heightFor(BuildContext context, double width) {
    final byWidth = (width * 0.72).clamp(240.0, 360.0);
    final byHeight = MediaQuery.sizeOf(context).height * 0.5;
    return math.min(byWidth, byHeight);
  }

  @override
  State<CarPhotoGallery> createState() => _CarPhotoGalleryState();
}

class _CarPhotoGalleryState extends State<CarPhotoGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openViewer() async {
    final photos = widget.car.photos;
    if (photos.isEmpty) return;

    final closedOn = await showPhotoViewer(
      context,
      photos: photos,
      initialIndex: _index,
    );

    // Come back to the photo they were last looking at, not to photo 1.
    if (!mounted || closedOn == null || closedOn == _index) return;
    if (_controller.hasClients) _controller.jumpToPage(closedOn);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.car.photos;
    final total = photos.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            CarPhotoGallery.heightFor(context, constraints.maxWidth);

        return Stack(
          children: [
            SizedBox(
              height: height,
              width: double.infinity,
              child: photos.isEmpty
                  ? const _GalleryMessage(
                      icon: Icons.directions_car,
                      label: 'לא צורפו תמונות למודעה',
                    )
                  : Semantics(
                      container: true,
                      // Read as a sentence, not as "photos dot 5".
                      label: total == 1
                          ? 'תמונה אחת במודעה'
                          : '$total תמונות במודעה',
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: total,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) => GestureDetector(
                          onTap: _openViewer,
                          child: Semantics(
                            image: true,
                            label: 'תמונה ${i + 1} מתוך $total',
                            child: CachedNetworkImage(
                              imageUrl: photos[i],
                              fit: BoxFit.cover,
                              // Without this the widget was empty until the
                              // bytes arrived, so the page visibly flashed.
                              placeholder: (_, __) => const Skeleton(
                                width: double.infinity,
                                height: double.infinity,
                                radius: 0,
                              ),
                              errorWidget: (_, __, ___) => const _GalleryMessage(
                                icon: Icons.image_not_supported_outlined,
                                label: 'לא הצלחנו לטעון את התמונה',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            // Top scrim, so the buttons stay legible over a bright photo.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.sm),
                child: Row(
                  children: [
                    _RoundAction(
                      key: CarPhotoGallery.backKey,
                      icon: Icons.arrow_forward,
                      tooltip: 'חזרה',
                      onPressed: () => popOrHome(context),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    _RoundAction.custom(
                      key: CarPhotoGallery.shareKey,
                      child: ShareListingButton(car: widget.car),
                    ),
                    const Spacer(),
                    if (total > 0) _expandButton(context, total),
                  ],
                ),
              ),
            ),
            // The seller badge and the position indicator share one row rather
            // than being two independent Positioneds. Centred absolutely, an
            // 8-dot pill ran under the badge on a 320px phone, and further
            // under it at a large text scale.
            PositionedDirectional(
              bottom: AppSpace.md,
              start: AppSpace.md,
              end: AppSpace.md,
              child: Row(
                children: [
                  SellerTypeBadge(type: widget.car.sellerType),
                  // Which photo of how many: dots while they are still
                  // countable, a number once they are not.
                  if (total > 1)
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: total <= CarPhotoGallery.maxDots
                              ? _Dots(total: total, index: _index)
                              : PhotoChip(
                                  child: Text('${_index + 1}/$total'),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// The one affordance that says the photos open. A buyer will not discover
  /// tap-to-zoom on their own, and zooming is the whole reason they are here.
  Widget _expandButton(BuildContext context, int total) {
    // One node, one label, one action. Without `onTap` here, excluding the
    // InkWell's own semantics would leave a button a screen reader can read
    // but not press.
    return Semantics(
      button: true,
      label: 'פתח את התמונות במסך מלא',
      excludeSemantics: true,
      onTap: _openViewer,
      child: Tooltip(
        message: 'פתח במסך מלא',
        child: InkWell(
          onTap: _openViewer,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          // A pill is shorter than a finger; the box around it is the tap
          // target, not the pill.
          child: SizedBox(
            key: CarPhotoGallery.expandKey,
            height: _RoundAction.size,
            child: Center(
              child: PhotoChip(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fullscreen,
                        size: 16, color: context.colors.onBrand),
                    const SizedBox(width: AppSpace.xs),
                    Text(total == 1 ? 'תמונה אחת' : '$total תמונות'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Back and share: solid surface circles, sized to the 48px tap target. The
/// bare `CircleAvatar` they replace was 40px, under the guideline on both
/// platforms.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  }) : child = null;

  /// For a control that brings its own icon, tooltip and handler — the share
  /// button. This only supplies the circle and the tap target.
  const _RoundAction.custom({super.key, required this.child})
      : icon = null,
        tooltip = null,
        onPressed = null;

  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final Widget? child;

  static const size = 48.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size,
        height: size,
        child: child ??
            IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(icon, color: context.colors.textPrimary),
              tooltip: tooltip,
              onPressed: onPressed,
            ),
      ),
    );
  }
}

/// Position indicator. On its own scrim so it survives a white car — plain
/// white dots on a photo of a white car are not there at all.
class _Dots extends StatelessWidget {
  const _Dots({required this.total, required this.index});

  final int total;
  final int index;

  @override
  Widget build(BuildContext context) {
    return PhotoChip(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.sm - 1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(total, (i) {
          final active = i == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: active
                  ? context.colors.onBrand
                  : context.colors.onBrand.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AppRadius.xs / 2),
            ),
          );
        }),
      ),
    );
  }
}

/// No photos, or a photo that would not load. One widget, because these were
/// two copies of the same block and only one of them ever got updated.
class _GalleryMessage extends StatelessWidget {
  const _GalleryMessage({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.tealLight,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpace.lg),
      // Scaled down rather than laid out freely: as a failed image's stand-in
      // this can be handed a box of almost any size.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: context.colors.teal),
            const SizedBox(height: AppSpace.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              // tealText is the ink that belongs on tealLight in both themes.
              // The size comes from the scale; only the colour is local.
              style: AppText.bodySm.copyWith(color: context.colors.tealText),
            ),
          ],
        ),
      ),
    );
  }
}
