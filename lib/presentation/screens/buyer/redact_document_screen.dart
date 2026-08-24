import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/document_redactor.dart';
import '../../../data/models/vehicle_document.dart';
import '../../widgets/primary_button_widget.dart';

/// Where the owner paints over what should not leave their phone.
///
/// **Why this screen exists at all.** A vehicle licence carries an ID number
/// and a home address; an insurance policy carries a policy number. The app
/// lets an owner show documents to buyers, which means the app is the thing
/// that publishes them, and asking someone to remember to crop a photograph
/// before uploading it is not a control.
///
/// **Why the owner marks and the app does not guess.** Finding a Hebrew
/// address in a photograph needs OCR, and the text recognition that runs
/// on-device covers Latin, Chinese, Japanese, Korean and Devanagari — not
/// Hebrew. An automatic redactor that silently missed the address would be
/// worse than none of this, because the owner would share the document
/// believing it had been cleaned. So the promise is kept small enough to keep:
/// what you mark is destroyed, and the photograph's location data goes whether
/// you marked anything or not.
///
/// What is drawn here is a preview. The pixels are destroyed on save, by
/// [DocumentRedactor], and the original is never stored.
class RedactDocumentScreen extends StatefulWidget {
  const RedactDocumentScreen({
    super.key,
    required this.bytes,
    required this.type,
  });

  /// The picked file, untouched.
  final Uint8List bytes;

  final DocumentType type;

  @override
  State<RedactDocumentScreen> createState() => _RedactDocumentScreenState();
}

class _RedactDocumentScreenState extends State<RedactDocumentScreen> {
  final _boxes = <RedactionBox>[];

  /// The rectangle being dragged right now, in fractions.
  RedactionBox? _dragging;
  Offset? _dragStart;

  bool _saving = false;
  String? _error;

  void _panStart(Offset local, Size box) {
    _dragStart = local;
    setState(() => _dragging = _rect(local, local, box));
  }

  void _panUpdate(Offset local, Size box) {
    final start = _dragStart;
    if (start == null) return;
    setState(() => _dragging = _rect(start, local, box));
  }

  void _panEnd() {
    final drawn = _dragging;
    _dragStart = null;
    setState(() {
      _dragging = null;
      // A press with no drag is not a redaction. Recording it would make the
      // "areas hidden" count on the record a number the owner cannot trust.
      if (drawn != null && drawn.isMeaningful) _boxes.add(drawn);
    });
  }

  /// Two corners in widget pixels to one rectangle in image fractions.
  ///
  /// Fractions because the picture on screen has been fitted to a phone and
  /// the picture that gets saved has been fitted to a Firestore document.
  /// Neither knows the other's scale, and a pixel rectangle would land in the
  /// wrong place in both.
  static RedactionBox _rect(Offset a, Offset b, Size box) {
    final left = (a.dx < b.dx ? a.dx : b.dx) / box.width;
    final top = (a.dy < b.dy ? a.dy : b.dy) / box.height;
    return RedactionBox(
      left: left,
      top: top,
      width: (a.dx - b.dx).abs() / box.width,
      height: (a.dy - b.dy).abs() / box.height,
    ).normalised;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    // Off the first frame so the button's spinner is painted before the
    // encoder takes the thread. A licence photographed at full resolution is
    // a few hundred milliseconds of work.
    await Future<void>.delayed(Duration.zero);
    final result = DocumentRedactor.prepare(widget.bytes, _boxes);

    if (!mounted) return;
    if (result == null) {
      setState(() {
        _saving = false;
        _error = 'לא הצלחנו להכין את הקובץ. נסו לצלם שוב או לבחור תמונה '
            'אחרת — קובץ שאינו תמונה, או גדול במיוחד, לא ייכנס.';
      });
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sensitive = widget.type.carriesPersonalData;

    return Scaffold(
      appBar: AppBar(title: const Text('סימון פרטים להסתרה')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sensitive
                        ? 'ב${widget.type.label} מופיעים לרוב מספר תעודת זהות '
                            'וכתובת מגורים. גררו אצבע מעליהם כדי להשחיר אותם.'
                        : 'גררו אצבע מעל כל פרט שלא תרצו שיישמר.',
                    style: AppText.body,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  // The line that separates what the app does from what it
                  // promises. Both halves matter, and the second one more.
                  Text(
                    'מה שתסמנו יימחק מהתמונה עצמה ולא ניתן יהיה לשחזר אותו. '
                    'נתוני המיקום של הצילום מוסרים תמיד, גם בלי סימון. '
                    'איננו מזהים פרטים בעצמנו — מה שלא תסמנו, יישמר.',
                    style: context.text.micro,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: Center(
                  child: _Canvas(
                    bytes: widget.bytes,
                    boxes: [..._boxes, if (_dragging != null) _dragging!],
                    onPanStart: _panStart,
                    onPanUpdate: _panUpdate,
                    onPanEnd: _panEnd,
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                child: Text(
                  _error!,
                  style: AppText.bodySm.copyWith(color: colors.errorRed),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        _boxes.isEmpty
                            ? 'לא סומן דבר'
                            : 'סומנו ${_boxes.length} אזורים',
                        style: context.text.caption,
                      ),
                      const Spacer(),
                      if (_boxes.isNotEmpty)
                        TextButton(
                          onPressed:
                              _saving ? null : () => setState(_boxes.removeLast),
                          child: const Text('בטל סימון אחרון'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  PrimaryButton(
                    label: _boxes.isEmpty ? 'שמור בלי סימון' : 'שמור',
                    loading: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picture with the black boxes over it, sized so that the widget's box
/// and the image's box are the same rectangle — which is what makes a drag
/// convertible to a fraction without knowing anything about the file.
class _Canvas extends StatefulWidget {
  const _Canvas({
    required this.bytes,
    required this.boxes,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final Uint8List bytes;
  final List<RedactionBox> boxes;
  final void Function(Offset local, Size box) onPanStart;
  final void Function(Offset local, Size box) onPanUpdate;
  final VoidCallback onPanEnd;

  @override
  State<_Canvas> createState() => _CanvasState();
}

class _CanvasState extends State<_Canvas> {
  double? _aspect;

  @override
  void initState() {
    super.initState();
    // The intrinsic size, taken from the decoded frame rather than by decoding
    // the file a second time here.
    Image.memory(widget.bytes)
        .image
        .resolve(const ImageConfiguration())
        .addListener(ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _aspect = info.image.width / info.image.height);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _aspect;
    if (aspect == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => widget.onPanStart(d.localPosition, size),
            onPanUpdate: (d) => widget.onPanUpdate(d.localPosition, size),
            onPanEnd: (_) => widget.onPanEnd(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(widget.bytes, fit: BoxFit.fill),
                for (final b in widget.boxes)
                  Positioned(
                    left: b.left * size.width,
                    top: b.top * size.height,
                    width: b.width * size.width,
                    height: b.height * size.height,
                    child: const ColoredBox(color: Colors.black),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
