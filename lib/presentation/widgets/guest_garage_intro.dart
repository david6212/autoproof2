import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// `show`, because intl exports a TextDirection of its own that shadows
// Flutter's and breaks every TextDirection.ltr in this file.
import 'package:intl/intl.dart' show NumberFormat;

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/gov_data_model.dart';
import '../providers/vehicle_draft_provider.dart';
import '../providers/vehicle_provider.dart';
import 'app_card.dart';
import 'primary_button_widget.dart';
import 'spec_tile.dart';

/// What a signed-out visitor meets in "הרכב שלי".
///
/// This used to be a login wall: a circle, a sentence about what a passport
/// would be, and a button asking for an account. It asked a stranger to commit
/// before they had anything to lose, which is the one thing every study of
/// this says not to do.
///
/// So the order is reversed. They type the plate of the car sitting outside,
/// and the registry answers with *their* car — make, model, year, test expiry.
/// Only then does the app ask for anything, and by then the sentence has
/// changed from "open an account" to "keep the file you just built".
///
/// The lookup is free to run for a guest: the government engine needs no
/// Firebase account, and the app already queries it for listings nobody has
/// signed in to see.
class GuestGarageIntro extends ConsumerStatefulWidget {
  const GuestGarageIntro({super.key});

  @override
  ConsumerState<GuestGarageIntro> createState() => _GuestGarageIntroState();
}

class _GuestGarageIntroState extends ConsumerState<GuestGarageIntro> {
  final _plate = TextEditingController();
  final _nickname = TextEditingController();
  bool _searching = false;

  /// Odometers read as thousands everywhere else in the app; a bare 61756 here
  /// looked like a part number.
  static final _km = NumberFormat('#,###', 'en');

  @override
  void dispose() {
    _plate.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    await ref.read(addVehicleControllerProvider.notifier).lookup(_plate.text);
    if (!mounted) return;
    setState(() => _searching = false);
  }

  /// Hands the draft to the app-scoped holder, then asks for the account.
  ///
  /// Storing before navigating matters: signing in ends on `context.go`, which
  /// disposes this screen and the lookup controller with it.
  void _keep(GovData car) {
    ref.read(vehicleDraftProvider.notifier).hold(
          VehicleDraft(
            gov: car,
            nickname: _nickname.text.trim(),
            // The registry's last test reading is the best odometer we have,
            // and it saves the owner walking out to read the dash.
            currentKm: car.lastTestKm ?? 0,
          ),
        );
    context.push('/login');
  }

  @override
  Widget build(BuildContext context) {
    final found = ref.watch(addVehicleControllerProvider).found;

    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: found == null ? _askStep() : _foundStep(found),
    );
  }

  List<Widget> _askStep() {
    final state = ref.watch(addVehicleControllerProvider);
    final colors = context.colors;

    return [
      const SizedBox(height: AppSpace.xl),
      Center(
        child: Container(
          width: 88,
          height: 88,
          decoration:
              BoxDecoration(color: colors.tealLight, shape: BoxShape.circle),
          child: Icon(Icons.directions_car_outlined,
              size: 40, color: colors.teal),
        ),
      ),
      const SizedBox(height: AppSpace.xl),
      // Plural, like every other line on this screen and like the empty
      // garage. The screen this replaced mixed the two registers in adjacent
      // sentences, which is the sort of seam a reader feels without naming.
      const Text(
        'מה רשום על הרכב שלכם?',
        textAlign: TextAlign.center,
        style: AppText.h2,
      ),
      const SizedBox(height: AppSpace.sm),
      Text(
        'הקלידו מספר רישוי ונראה לכם מה משרד התחבורה מחזיק על הרכב — '
        'בלי הרשמה.',
        textAlign: TextAlign.center,
        style: context.text.bodyMuted,
      ),
      const SizedBox(height: AppSpace.xl),
      TextField(
        controller: _plate,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
        ),
        decoration: const InputDecoration(
          labelText: 'מספר רישוי',
          hintText: '12345678',
          hintTextDirection: TextDirection.ltr,
        ),
        onSubmitted: (_) => _search(),
      ),
      if (state.error != null) ...[
        const SizedBox(height: AppSpace.md),
        _ErrorNote(message: state.error!),
      ],
      const SizedBox(height: AppSpace.lg),
      PrimaryButton(
        label: 'הצג את הרכב שלי',
        loading: _searching,
        onPressed: _search,
      ),
    ];
  }

  List<Widget> _foundStep(GovData car) {
    final name = car.commercialName.isNotEmpty ? car.commercialName : car.model;

    return [
      const Text('זה הרכב שלכם', style: AppText.h2),
      const SizedBox(height: AppSpace.xs),
      Text(
        'הנתונים למטה הגיעו ממרשם הרכב, לא מאיתנו.',
        style: context.text.bodyMuted,
      ),
      const SizedBox(height: AppSpace.lg),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${car.make} $name'.trim(), style: AppText.title),
            const SizedBox(height: AppSpace.xs),
            Text('${car.year} · ${car.color}', style: context.text.caption),
            const SizedBox(height: AppSpace.lg),
            SpecTileGrid(tiles: [
              if (car.fuelType.isNotEmpty)
                SpecTile(
                  icon: Icons.local_gas_station_outlined,
                  label: 'סוג דלק',
                  value: car.fuelType,
                ),
              if (car.color.isNotEmpty)
                SpecTile(
                  icon: Icons.palette_outlined,
                  label: 'צבע',
                  value: car.color,
                ),
              if (car.licenseExpiry != null)
                SpecTile(
                  icon: Icons.event_available_outlined,
                  label: 'תוקף טסט',
                  value: car.licenseExpiryDisplay,
                ),
              if (car.lastTestKm != null)
                SpecTile(
                  icon: Icons.speed_outlined,
                  label: 'ק"מ בטסט האחרון',
                  value: _km.format(car.lastTestKm),
                ),
            ]),
          ],
        ),
      ),
      const SizedBox(height: AppSpace.lg),
      TextField(
        controller: _nickname,
        decoration: const InputDecoration(
          labelText: 'כינוי לרכב (לא חובה)',
          hintText: 'האוטו של אמא',
        ),
      ),
      const SizedBox(height: AppSpace.xl),
      // The ask, at the point where there is something to keep. It names what
      // is being saved rather than what is being opened — the file already
      // exists on screen, and an account is how it survives closing the app.
      PrimaryButton(
        label: 'שמרו את התיק הזה',
        onPressed: () => _keep(car),
      ),
      const SizedBox(height: AppSpace.sm),
      Text(
        'החשבון שומר את התיק ומאפשר לתעד טיפולים. '
        'הנתונים שראיתם למעלה זמינים גם בלעדיו.',
        textAlign: TextAlign.center,
        style: context.text.micro,
      ),
      const SizedBox(height: AppSpace.sm),
      Center(
        child: TextButton(
          onPressed: () =>
              ref.read(addVehicleControllerProvider.notifier).back(),
          child: const Text('זה לא הרכב שלי'),
        ),
      ),
    ];
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: colors.errorBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: colors.errorRed),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              message,
              style: AppText.bodySm.copyWith(color: colors.errorRed),
            ),
          ),
        ],
      ),
    );
  }
}
