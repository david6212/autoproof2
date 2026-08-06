import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';

/// Chrome that floats over a photo.
///
/// A listing photo can be any colour, so overlay controls cannot borrow the
/// theme's `surface` for contrast — a white pill is invisible on a white car.
/// Everything here sits on a fixed black scrim and paints in `onBrand`, which
/// is the same in both themes precisely because what it sits on is.
class PhotoChip extends StatelessWidget {
  const PhotoChip({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpace.sm + 2,
      vertical: AppSpace.xs + 1,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Measured, not guessed: white on black at this alpha over a pure-white
  /// photo — the worst case — comes out at 5.7:1, clear of the 4.5:1 floor for
  /// small text. `photo_gallery_test` pins it.
  static const scrimAlpha = 0.6;

  /// The scrim itself, for callers that need it on a shape of their own.
  static Color scrim(double alpha) => Colors.black.withValues(alpha: alpha);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scrim(scrimAlpha),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: DefaultTextStyle.merge(
        // Size from the scale, colour from the palette: `onBrand` is white in
        // both themes because the scrim under it is dark in both.
        style: AppText.bodySm.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colors.onBrand,
        ),
        child: child,
      ),
    );
  }
}

/// A round icon button on the same scrim, sized to the 48px tap target rather
/// than to the icon.
class PhotoIconButton extends StatelessWidget {
  const PhotoIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback onPressed;

  /// Doubles as the semantics label — these buttons have no visible text.
  final String tooltip;

  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PhotoChip.scrim(PhotoChip.scrimAlpha),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 20, color: context.colors.onBrand),
          ),
        ),
      ),
    );
  }
}

/// Opens [photos] full screen, starting at [initialIndex].
///
/// Resolves to the index the viewer was closed on, so the caller's carousel can
/// stay in step with what the buyer was last looking at.
Future<int?> showPhotoViewer(
  BuildContext context, {
  required List<String> photos,
  int initialIndex = 0,
}) {
  return Navigator.of(context).push<int>(
    MaterialPageRoute<int>(
      fullscreenDialog: true,
      builder: (_) => PhotoViewer(photos: photos, initialIndex: initialIndex),
    ),
  );
}

/// Full-screen photo inspection: swipe between photos, pinch or double-tap to
/// zoom.
///
/// Someone deciding whether to drive an hour to see a car zooms into the wheel
/// arch. A 280px-tall carousel cannot answer that question, so this exists.
///
/// The background is black in both themes on purpose. This is the one surface
/// in the app that is not a container for the app's own content — it is a
/// darkroom for someone else's photo, and a light wash behind a photo changes
/// how the photo reads.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  final List<String> photos;
  final int initialIndex;

  /// Says who the photos came from and what we did not do to them. The gallery
  /// makes no claim about a photo's accuracy, so this states the limit rather
  /// than implying one was checked.
  static const sourceNote = 'התמונות הועלו על ידי המוכר ולא נבדקו על ידינו';

  static const zoomHint = 'צביטה או הקשה כפולה להגדלה';

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  final _zoom = TransformationController();

  late int _index = widget.initialIndex;
  bool _zoomed = false;
  Offset _lastTap = Offset.zero;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_watchZoom);
  }

  @override
  void dispose() {
    _zoom.removeListener(_watchZoom);
    _zoom.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// A zoomed photo owns the horizontal drag — otherwise panning across a
  /// magnified wheel arch flips to the next photo instead.
  void _watchZoom() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _toggleZoom() {
    if (_zoomed) {
      _zoom.value = Matrix4.identity();
      return;
    }
    const scale = 2.5;
    _zoom.value = Matrix4.identity()
      ..translate(-_lastTap.dx * (scale - 1), -_lastTap.dy * (scale - 1))
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photos.length;

    return Scaffold(
      backgroundColor: Colors.black,
      // SizedBox.expand, not a bare Stack: a Scaffold hands its body a *loose*
      // height, so a Stack sized by its children collapsed to the height of
      // the top button row — 64px of photo, full width, with the bottom
      // caption floating above the top of the screen. Caught by
      // `photo_gallery_test`, which measures the viewer's height.
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pages,
                itemCount: total,
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                onPageChanged: (i) {
                  // Each photo starts unzoomed, or the next one arrives
                  // already magnified into a corner.
                  _zoom.value = Matrix4.identity();
                  setState(() => _index = i);
                },
                itemBuilder: (context, i) => GestureDetector(
                  onDoubleTapDown: (d) => _lastTap = d.localPosition,
                  onDoubleTap: _toggleZoom,
                  child: InteractiveViewer(
                    transformationController: _zoom,
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: Semantics(
                        image: true,
                        label: 'תמונה ${i + 1} מתוך $total',
                        child: CachedNetworkImage(
                          imageUrl: widget.photos[i],
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const _ViewerStatus(
                            icon: Icons.image_outlined,
                            label: 'טוען תמונה...',
                          ),
                          errorWidget: (_, __, ___) => const _ViewerStatus(
                            icon: Icons.image_not_supported_outlined,
                            label: 'לא הצלחנו לטעון את התמונה',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.sm),
                child: Row(
                  children: [
                    PhotoIconButton(
                      icon: Icons.close,
                      tooltip: 'סגור',
                      onPressed: () => Navigator.of(context).pop(_index),
                    ),
                    const Spacer(),
                    if (total > 1)
                      Semantics(
                        // "2/3" is read out character by character; this is
                        // the sentence it stands for.
                        label: 'תמונה ${_index + 1} מתוך $total',
                        excludeSemantics: true,
                        child: PhotoChip(child: Text('${_index + 1}/$total')),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_zoomed) ...[
                        const PhotoChip(child: Text(PhotoViewer.zoomHint)),
                        const SizedBox(height: AppSpace.sm),
                      ],
                      const PhotoChip(
                        child: Text(
                          PhotoViewer.sourceNote,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading and failure inside the viewer: on black, so it uses `onBrand`
/// rather than the theme's text colours.
class _ViewerStatus extends StatelessWidget {
  const _ViewerStatus({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.onBrand.withValues(alpha: 0.7);
    // Scaled down rather than laid out freely: this sits where the image
    // would, and the image widget can hand it a box of almost any size.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: ink),
          const SizedBox(height: AppSpace.md),
          Text(label, style: AppText.bodySm.copyWith(color: ink)),
        ],
      ),
    );
  }
}
