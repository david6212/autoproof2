import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/vehicle_document.dart';
import '../providers/vehicle_provider.dart';
import 'error_retry.dart';

/// Opens one attached document.
///
/// The bytes are not on the record — they are in a `file/blob` document one
/// level down, fetched only when someone actually looks. That is what keeps
/// the drawer's list view cheap: a passport with eight scans in it is eight
/// small records, not seven megabytes nobody asked for.
///
/// Every fetch is checked against the security rules, which is the difference
/// that matters against a Storage download URL: when the owner turns sharing
/// off, this stops working, for everyone, immediately.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({
    super.key,
    required this.vehicleId,
    required this.document,
  });

  final String vehicleId;
  final VehicleDocument document;

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _bytes = ref
        .read(documentActionsProvider)
        .bytes(widget.vehicleId, widget.document.id);
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(doc.displayTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<Uint8List?>(
                future: _bytes,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: ErrorRetry(
                        compact: true,
                        message: 'לא הצלחנו לפתוח את המסמך',
                        onRetry: () => setState(_load),
                      ),
                    );
                  }
                  final bytes = snap.data;
                  if (bytes == null) {
                    // A record whose file is gone. Said plainly rather than
                    // drawn as an empty frame the reader has to interpret.
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpace.xl),
                        child: Text(
                          'הקובץ של המסמך הזה אינו נמצא.',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return InteractiveViewer(
                    maxScale: 5,
                    child: Center(child: Image.memory(bytes)),
                  );
                },
              ),
            ),
            if (doc.wasRedacted)
              Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Text(
                  // A statement of what was done, not of what is safe. The
                  // count is the owner's own marking, recorded at save time.
                  doc.redactedAreas == 1
                      ? 'אזור אחד הושחר במסמך הזה לפני השמירה.'
                      : '${doc.redactedAreas} אזורים הושחרו במסמך הזה לפני השמירה.',
                  textAlign: TextAlign.center,
                  style: AppText.bodySm.copyWith(color: context.colors.textSubtle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
