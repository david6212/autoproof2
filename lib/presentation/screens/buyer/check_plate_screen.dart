import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/validators.dart';
import '../../../data/sources/remote/gov_api_service.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/gov_api_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/gov_data_card_widget.dart';
import '../../widgets/primary_button_widget.dart';

/// Check any car, by its plate. No account, no listing, no ownership claim.
///
/// **This is the app's one capability that needs nothing from us.** Everything
/// else depends on somebody having published something: the feed needs
/// listings, the passport needs an owner, the reviews need a community. The
/// registry answers about every car on the road — and the moment a buyer
/// actually has a plate in front of them is standing at a viewing, or reading
/// somebody else's advert, neither of which starts in this app.
///
/// Until now the only way in was "הוסף רכב" in the garage, which asks the
/// reader to say the car is theirs. A buyer checking a stranger's car had to
/// lie to the form to get an answer.
///
/// **The plate is not stored.** Not in the cache (see `GovCache`), not in
/// analytics (`vehicleLookup()` takes no argument, deliberately), and not in
/// any document — a list of plates somebody checked is exactly the kind of
/// record this app has refused to keep.
class CheckPlateScreen extends ConsumerStatefulWidget {
  const CheckPlateScreen({super.key, this.initialPlate});

  /// Prefilled when the reader arrives from somewhere that already has a
  /// number — the passport's "check another car", for instance.
  final String? initialPlate;

  @override
  ConsumerState<CheckPlateScreen> createState() => _CheckPlateScreenState();
}

class _CheckPlateScreenState extends ConsumerState<CheckPlateScreen> {
  late final TextEditingController _plate =
      TextEditingController(text: widget.initialPlate ?? '');

  /// The plate actually submitted, which is what the result is keyed on. Kept
  /// apart from the field so editing the number does not silently change what
  /// the card below is describing.
  String? _asked;
  String? _error;

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  void _check() {
    FocusScope.of(context).unfocus();
    final error = Validators.plate(_plate.text);
    setState(() {
      _error = error;
      _asked = error == null ? _plate.text.trim() : null;
    });
    if (error == null) ref.read(analyticsHelperProvider).vehicleLookup();
  }

  @override
  Widget build(BuildContext context) {
    final asked = _asked;

    return Scaffold(
      appBar: AppBar(title: const Text('בדיקת רכב')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            Text(
              'ראיתם רכב? הקלידו את מספר הרישוי ותראו מה רשום עליו במרשם '
              'הרכב — גם אם הוא לא מפורסם כאן ולא שייך לכם.',
              style: context.text.bodyMuted,
            ),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _plate,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textDirection: TextDirection.ltr,
              autofocus: widget.initialPlate == null,
              decoration: const InputDecoration(
                labelText: 'מספר רישוי',
                hintText: '12345678',
              ),
              onSubmitted: (_) => _check(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(_error!,
                  style: context.text.micro
                      .copyWith(color: context.colors.errorRed)),
            ],
            const SizedBox(height: AppSpace.lg),
            PrimaryButton(label: 'בדקו', onPressed: _check),
            const SizedBox(height: AppSpace.sm),
            Text(
              'מספר הרישוי משמש לשאילתה אחת מול המרשם ואינו נשמר — לא אצלנו '
              'ולא במכשיר.',
              style: context.text.micro,
            ),
            if (asked != null) ...[
              const SizedBox(height: AppSpace.xl),
              _Result(plate: asked),
            ],
          ],
        ),
      ),
    );
  }
}

class _Result extends ConsumerWidget {
  const _Result({required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(govDataForPlateProvider(plate));

    return result.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      // A plate the registry has never heard of is an answer, and a different
      // one from "the registry did not reply". The provider already separates
      // them; this shows the difference rather than flattening it.
      error: (e, _) => _Note(
        icon: Icons.cloud_off,
        title: e is GovApiException && e.kind == GovApiErrorKind.notFound
            ? 'המספר לא נמצא במרשם'
            : 'לא הצלחנו להגיע למרשם כרגע',
        body: e is GovApiException
            ? e.message
            : 'בדקו את החיבור לאינטרנט ונסו שוב.',
        onRetry: () => ref.invalidate(govDataForPlateProvider(plate)),
      ),
      data: (data) {
        if (data == null) {
          return const _Note(
            icon: Icons.search_off,
            title: 'המספר לא נמצא במרשם',
            body: 'ייתכן שהוקלד מספר שגוי, או שהרכב אינו במרשם הפעיל.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GovDataCard(data: data),
            const SizedBox(height: AppSpace.lg),
            // The obvious next step, and the honest one: the app cannot tell
            // whether this car is any good — it can hand the reader the
            // records and the people who look at cars for a living.
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('מה עכשיו?', style: AppText.subtitle),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'הנתונים כאן הם מה שהמרשם רשם, ולא בדיקה של הרכב עצמו. '
                    'לפני קנייה כדאי לבדוק אותו פיזית.',
                    style: context.text.micro,
                  ),
                  const SizedBox(height: AppSpace.md),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.engineering_outlined, size: 18),
                    label: const Text('מכוני בדיקה מורשים'),
                    // The screen takes a listing id to pre-fill an area; there
                    // is no listing here, and it already treats an unknown id
                    // as "no area", which is the right behaviour for a plate
                    // somebody typed in off the street.
                    onPressed: () => context.push('/inspectors/-'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.title,
    required this.body,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(icon, size: 34, color: context.colors.textSubtle),
          const SizedBox(height: AppSpace.md),
          Text(title, style: AppText.subtitle, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.xs),
          Text(body, style: context.text.micro, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpace.md),
            TextButton(onPressed: onRetry, child: const Text('נסו שוב')),
          ],
          const SizedBox(height: AppSpace.sm),
          Text(AppStrings.registrySourceNote,
              style: context.text.micro, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
