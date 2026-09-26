import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/service_record.dart';
import '../providers/vehicle_provider.dart';

/// One service receipt, fetched when it is opened and not before.
///
/// **The owner's screen only.** The bytes live in
/// `vehicles/{id}/services/{sid}/file/blob`, which the rules keep to the
/// owner — the record above it is readable to a buyer because a service
/// history is what a passport is for, while the invoice behind it carries a
/// name and often an address and is not.
///
/// Fetched lazily for the same reason the passport's documents are: the
/// timeline would otherwise download every invoice in it to draw a list.
class ReceiptViewerScreen extends ConsumerStatefulWidget {
  const ReceiptViewerScreen({
    super.key,
    required this.vehicleId,
    required this.record,
  });

  final String vehicleId;
  final ServiceRecord record;

  @override
  ConsumerState<ReceiptViewerScreen> createState() =>
      _ReceiptViewerScreenState();
}

class _ReceiptViewerScreenState extends ConsumerState<ReceiptViewerScreen> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = ref.read(serviceRepositoryProvider).receiptBytes(
          widget.vehicleId,
          widget.record.id,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('קבלה')),
      body: SafeArea(
        child: FutureBuilder<Uint8List?>(
          future: _bytes,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final bytes = snap.data;
            if (bytes == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.xxl),
                  child: Text(
                    'לא הצלחנו לפתוח את הקבלה.',
                    style: context.text.bodyMuted,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Center(child: Image.memory(bytes)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Text(
                    '${widget.record.title} · הקבלה נשמרת בתיק שלכם בלבד '
                    'ואינה מוצגת לקונים.',
                    style: context.text.micro,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
