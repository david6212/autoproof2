import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../providers/gov_api_provider.dart';
import '../../widgets/gov_data_card_widget.dart';
import '../../widgets/plate_text.dart';

/// The official registry record behind one listing.
///
/// This screen used to ask the reader to type a plate, and arrived with the
/// listing's plate already filled in — which meant a listing handed its plate
/// to every visitor who tapped through, and put it in the address bar on the
/// way. Sellers tape over the plate before photographing a car; an app that
/// prints the number on the next screen has overruled them.
///
/// So it now takes the car's id, reads the plate without showing it, and
/// displays exactly what it always displayed: the ministry's record. The only
/// reader who sees the number itself is the person who owns the listing.
class VehicleHistoryScreen extends ConsumerStatefulWidget {
  const VehicleHistoryScreen({super.key, required this.carId});

  /// The listing's document id — not its plate.
  final String carId;

  @override
  ConsumerState<VehicleHistoryScreen> createState() =>
      _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends ConsumerState<VehicleHistoryScreen> {
  /// The plate already looked up, so a rebuild does not re-query the registry.
  String? _searched;

  void _lookup(String plate) {
    if (_searched == plate) return;
    _searched = plate;
    ref.read(analyticsHelperProvider).vehicleLookup();
    ref.read(govLookupControllerProvider.notifier).search(plate);
  }

  @override
  Widget build(BuildContext context) {
    final car = ref.watch(carByIdProvider(widget.carId));
    final result = ref.watch(govLookupControllerProvider);
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    final plate = car.valueOrNull?.plate ?? '';
    if (plate.isNotEmpty) {
      // Fired from build because the plate only arrives with the car, and
      // waiting for a second frame would show an empty screen first.
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup(plate));
    }

    // The seller looking at their own listing already knows the number, and
    // hiding it from them would read as the app not trusting them with it.
    final isOwner = uid != null && car.valueOrNull?.sellerId == uid;

    return Scaffold(
      appBar: AppBar(title: const Text('הרשומה הרשמית')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (plate.isNotEmpty) _PlateLine(plate: plate, full: isOwner),
              const SizedBox(height: 20),
              if (car.hasError)
                _ErrorBox(
                  message: 'לא הצלחנו לטעון את המודעה.',
                  onRetry: () => ref.invalidate(carByIdProvider(widget.carId)),
                )
              else if (car.isLoading || (plate.isNotEmpty && result.isLoading))
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (car.valueOrNull == null)
                const _Gone()
              else
                result.when(
                  data: (data) => data == null
                      ? const _NotInRegistry()
                      : GovDataCard(data: data),
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => _ErrorBox(
                    message: err.toString(),
                    onRetry: () {
                      _searched = null;
                      _lookup(plate);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The plate, starred out unless the reader owns the listing.
///
/// Shown rather than omitted because the reader should know the app holds the
/// number and looked the car up with it — that is the whole basis of what is
/// below. Hiding the fact as well as the digits would leave the record looking
/// like it belongs to no particular car.
class _PlateLine extends StatelessWidget {
  const _PlateLine({required this.plate, required this.full});

  final String plate;
  final bool full;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PlateText(
          plate,
          revealable: full,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          full
              ? 'המודעה שלך. קונים רואים כוכביות — הקישו כדי לראות את המספר'
              : 'מספר הרישוי מוסתר. הנתונים למטה נשלפו ממנו',
          textAlign: TextAlign.center,
          style: context.text.bodySmMuted,
        ),
      ],
    );
  }
}

/// The registry answered, and has no such vehicle.
class _NotInRegistry extends StatelessWidget {
  const _NotInRegistry();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.help_outline, size: 56, color: context.colors.textSubtle),
          const SizedBox(height: 12),
          Text(
            'הרכב הזה לא נמצא במרשם הפעיל',
            style: TextStyle(color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// The listing itself is gone — removed or sold while the link was open.
class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.directions_car_outlined,
              size: 56, color: context.colors.textSubtle),
          const SizedBox(height: 12),
          Text(
            'המודעה הזו כבר לא קיימת',
            style: TextStyle(color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.errorBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: context.colors.errorRed, size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.errorRed),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
        ],
      ),
    );
  }
}
