import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/place.dart';
import '../../providers/auth_provider.dart';
import '../../providers/place_provider.dart';
import '../../widgets/primary_button_widget.dart';

/// Adding a garage or a car wash that is not in the directory yet.
///
/// **Everything added here is community content, and the screen says so before
/// the person commits, not after.** There is no register of repair garages to
/// check a name against, so an entry is exactly as good as the care taken by
/// whoever typed it — and the next reader is entitled to know that is what
/// they are reading.
class AddPlaceScreen extends ConsumerStatefulWidget {
  const AddPlaceScreen({
    super.key,
    this.initialCategory,
    this.initialName,
  });

  /// The stored id of a [PlaceCategory], when the screen was opened from a
  /// context that already knows — the washes row passes `car_wash`.
  final String? initialCategory;

  /// What the person had already typed into the garage field.
  final String? initialName;

  @override
  ConsumerState<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends ConsumerState<AddPlaceScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();

  late PlaceCategory _category;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName ?? '';
    _category = PlaceCategoryX.fromId(widget.initialCategory ?? '') ??
        PlaceCategory.garageMechanical;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'צריך למלא שם');
      return;
    }
    if (_city.text.trim().isEmpty) {
      setState(() => _error = 'צריך למלא עיר');
      return;
    }

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    // Said before the write, not after. Somebody who did not mean to publish
    // gets to stop here.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('להוסיף לרשימה?'),
        content: const Text(
          'המקום יסומן "נוסף על ידי הקהילה" ויוצג לכל מי שמחפש. אנחנו לא '
          'בודקים את הפרטים — ודאו שהם נכונים.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('ביטול')),
          TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('הוסף')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      final id = await ref.read(placeRepositoryProvider).addCommunityPlace(
            uid: uid,
            category: _category,
            name: _name.text,
            address: _address.text,
            city: _city.text,
            phone: _phone.text,
          );
      if (!mounted) return;
      // Hands the new id back, so the field that sent us here can link the
      // service record to it without the person searching for what they just
      // typed.
      Navigator.of(context).pop(id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'לא הצלחנו להוסיף את המקום. נסו שוב.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('הוספת מקום')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: colors.warnBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'מקומות שנוספים כאן מסומנים "נוסף על ידי הקהילה". אנחנו לא '
                'מאמתים אותם מול שום מרשם.',
                style: AppText.bodySm.copyWith(color: colors.warnText),
              ),
            ),
            const SizedBox(height: AppSpace.lg),

            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'שם המקום'),
            ),
            const SizedBox(height: AppSpace.lg),

            Text('סוג', style: context.text.caption),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final c in PlaceCategory.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _category == c,
                    showCheckmark: false,
                    selectedColor: colors.teal,
                    backgroundColor: colors.background,
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _category == c
                          ? colors.onBrand
                          : colors.textMuted,
                    ),
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),

            TextField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'עיר'),
            ),
            const SizedBox(height: AppSpace.lg),

            TextField(
              controller: _address,
              decoration:
                  const InputDecoration(labelText: 'כתובת (לא חובה)'),
            ),
            const SizedBox(height: AppSpace.lg),

            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'טלפון (לא חובה)'),
            ),

            if (_error != null) ...[
              const SizedBox(height: AppSpace.md),
              Text(_error!,
                  style: AppText.bodySm.copyWith(color: colors.errorRed)),
            ],
            const SizedBox(height: AppSpace.xl),

            PrimaryButton(
              label: 'הוסף לרשימה',
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'המיקום על המפה לא נשמר עדיין — מקום שנוסף כאן יימצא לפי שם '
              'ועיר. אפשר יהיה להוסיף מיקום בהמשך.',
              style: context.text.micro,
            ),
          ],
        ),
      ),
    );
  }
}
