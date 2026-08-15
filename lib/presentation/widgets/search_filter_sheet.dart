import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/constants/car_catalog.dart';
import '../../data/models/car_model.dart';
import '../providers/cars_provider.dart';
import '../../core/theme/app_text.dart';

/// Opens the advanced buyer filter sheet. Functional filters (model, hand,
/// price, year, km, area) are committed to [carFiltersProvider] on apply;
/// the remaining sections are visual for now until the data is stored.
Future<void> showSearchFilterSheet(
    BuildContext context, List<CarModel> cars) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: _FilterSheet(cars: cars),
    ),
  );
}

const _areas = [
  'תל אביב', 'ירושלים', 'חיפה', 'ראשון לציון', 'פתח תקווה',
  'באר שבע', 'נתניה', 'אשדוד', 'רמת גן', 'הרצליה',
];

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.cars});
  final List<CarModel> cars;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late CarFilters _draft;

  /// Must stay in the same order as `_ColorDots._colors`, which draws them.
  static const _colorCats = [
    'לבן',
    'שחור',
    'כסף',
    'אפור',
    'כחול',
    'אדום',
    'ירוק',
    'חום',
    'צהוב',
  ];


  /// Both ends of each range. Held rather than rebuilt every frame, or the
  /// caret would jump back to the start on each keystroke.
  late final TextEditingController _priceMinCtl;
  late final TextEditingController _priceMaxCtl;
  late final TextEditingController _yearMinCtl;
  late final TextEditingController _yearMaxCtl;
  late final TextEditingController _kmMinCtl;
  late final TextEditingController _kmMaxCtl;

  /// An empty field means "no bound on this side" — a real answer, so a range
  /// nobody has touched opens blank instead of showing numbers the buyer never
  /// chose.
  String _shown(num value, num sentinel) =>
      value == sentinel ? '' : value.round().toString();

  @override
  void initState() {
    super.initState();
    _draft = ref.read(carFiltersProvider);

    _priceMinCtl = TextEditingController(
        text: _shown(_draft.minPrice, CarFilters.priceFloor));
    _priceMaxCtl = TextEditingController(
        text: _shown(_draft.maxPrice, CarFilters.priceCap));
    _yearMinCtl = TextEditingController(
        text: _shown(_draft.minYear, CarFilters.yearFloor));
    _yearMaxCtl = TextEditingController(
        text: _shown(_draft.maxYear, CarFilters.yearCap));
    _kmMinCtl =
        TextEditingController(text: _shown(_draft.minKm, CarFilters.kmFloor));
    _kmMaxCtl =
        TextEditingController(text: _shown(_draft.maxKm, CarFilters.kmCap));

    _priceMinCtl.addListener(() => _typed(_priceMinCtl,
        empty: CarFilters.priceFloor,
        apply: (v) => _draft = _draft.copyWith(minPrice: v)));
    _priceMaxCtl.addListener(() => _typed(_priceMaxCtl,
        empty: CarFilters.priceCap,
        apply: (v) => _draft = _draft.copyWith(maxPrice: v)));

    // A half-typed "20" is not a year. Applying it would empty the list
    // mid-keystroke and look like the filter is broken.
    _yearMinCtl.addListener(() => _typed(_yearMinCtl,
        empty: CarFilters.yearFloor.toDouble(),
        valid: _looksLikeYear,
        apply: (v) => _draft = _draft.copyWith(minYear: v.round())));
    _yearMaxCtl.addListener(() => _typed(_yearMaxCtl,
        empty: CarFilters.yearCap.toDouble(),
        valid: _looksLikeYear,
        apply: (v) => _draft = _draft.copyWith(maxYear: v.round())));

    _kmMinCtl.addListener(() => _typed(_kmMinCtl,
        empty: CarFilters.kmFloor.toDouble(),
        apply: (v) => _draft = _draft.copyWith(minKm: v.round())));
    _kmMaxCtl.addListener(() => _typed(_kmMaxCtl,
        empty: CarFilters.kmCap.toDouble(),
        apply: (v) => _draft = _draft.copyWith(maxKm: v.round())));
  }

  static bool _looksLikeYear(double v) => v >= 1900 && v <= CarFilters.yearCap;

  /// Applies what was typed. Empty restores the "no bound" sentinel; anything
  /// not yet a usable number is ignored until it becomes one.
  void _typed(
    TextEditingController c, {
    required double empty,
    required void Function(double) apply,
    bool Function(double)? valid,
  }) {
    final raw = c.text.trim();
    if (raw.isEmpty) {
      setState(() => apply(empty));
      return;
    }
    final v = double.tryParse(raw);
    if (v == null || (valid != null && !valid(v))) return;
    setState(() => apply(v));
  }

  @override
  void dispose() {
    for (final c in [
      _priceMinCtl,
      _priceMaxCtl,
      _yearMinCtl,
      _yearMaxCtl,
      _kmMinCtl,
      _kmMaxCtl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- functional setters ----
  void _setHand(String v) {
    setState(() {
      _draft = v == 'יד 1 בלבד'
          ? _draft.copyWith(maxHand: 1)
          : v == 'עד יד 2'
              ? _draft.copyWith(maxHand: 2)
              : _draft.copyWith(clearHand: true);
    });
  }

  String get _handLabel => _draft.maxHand == 1
      ? 'יד 1 בלבד'
      : _draft.maxHand == 2
          ? 'עד יד 2'
          : 'ללא הגבלה';

  bool _matches(CarModel c, String query) {
    final f = _draft;
    if (f.make != null && c.make != f.make) return false;
    if (f.model != null && c.model != f.model) return false;
    if (f.maxHand != null && c.hand > f.maxHand!) return false;
    if (f.fuel != null && c.fuelCategory != f.fuel) return false;
    if (f.colorCat != null && c.colorCategory != f.colorCat) return false;
    if (f.ownership == 'פרטית' && !c.isPrivateOwnership) return false;
    if (f.ownership == 'ליסינג/חברה' && c.isPrivateOwnership) return false;
    // Both ends, matching `filteredCarsProvider`. This drives the live count
    // on the apply button, so if it disagreed with the real filter the button
    // would promise a number of results the list then would not show.
    if (c.price < f.minPrice || c.price > f.maxPrice) return false;
    if (c.year < f.minYear || c.year > f.maxYear) return false;
    if (c.km < f.minKm || c.km > f.maxKm) return false;
    if (f.area != null && c.area != f.area) return false;
    if (query.isNotEmpty) {
      final hay = '${c.make} ${c.model} ${c.area} ${c.plate}'.toLowerCase();
      if (!hay.contains(query.toLowerCase())) return false;
    }
    return true;
  }

  void _clearAll() {
    setState(() => _draft = const CarFilters());
    // The fields hold their own text, so resetting the draft alone would clear
    // the filter while still showing the numbers it was cleared from — and the
    // listeners would then type them straight back in.
    for (final c in [
      _priceMinCtl,
      _priceMaxCtl,
      _yearMinCtl,
      _yearMaxCtl,
      _kmMinCtl,
      _kmMaxCtl,
    ]) {
      c.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(carSearchProvider);
    final count = widget.cars.where((c) => _matches(c, query)).length;

    final models =
        _draft.make == null ? const <String>[] : (kCarCatalog[_draft.make] ?? const []);

    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: context.colors.cardBorder,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              const Text('סינון רכבים מתקדם',
                  style: AppText.h2),
              const Spacer(),
              _ClearButton(onTap: _clearAll),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Manufacturer + model (from the Israel-wide catalogue).
              Row(
                children: [
                  Expanded(
                    child: _Dropdown<String?>(
                      label: 'יצרן',
                      value: _draft.make,
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('כל היצרנים')),
                        for (final m in kCarMakes)
                          DropdownMenuItem(value: m, child: Text(m)),
                      ],
                      onChanged: (v) => setState(() => _draft = v == null
                          ? _draft.copyWith(clearMake: true, clearModel: true)
                          // Changing make resets the chosen model.
                          : _draft.copyWith(make: v, clearModel: true)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Dropdown<String?>(
                      label: 'דגם',
                      value: _draft.model,
                      items: [
                        DropdownMenuItem(
                            value: null,
                            child: Text(_draft.make == null
                                ? 'בחר יצרן'
                                : 'כל הדגמים')),
                        for (final m in models)
                          DropdownMenuItem(value: m, child: Text(m)),
                      ],
                      onChanged: _draft.make == null
                          ? null
                          : (v) => setState(() => _draft = v == null
                              ? _draft.copyWith(clearModel: true)
                              : _draft.copyWith(model: v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _PillGroup(
                label: 'יד (בעלות קודמת)',
                options: const ['עד יד 2', 'יד 1 בלבד', 'ללא הגבלה'],
                selected: _handLabel,
                onSelect: _setHand,
              ),
              const SizedBox(height: 16),

              _PillGroup(
                label: 'בעלות נוכחית',
                options: const ['פרטית', 'ליסינג/חברה', 'הכל'],
                selected: _draft.ownership ?? 'הכל',
                onSelect: (v) => setState(() => _draft = v == 'הכל'
                    ? _draft.copyWith(clearOwnership: true)
                    : _draft.copyWith(ownership: v)),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: _Dropdown<String>(
                      label: 'נפח מנוע (סמ"ק)',
                      value: _draft.engineRange ?? 'ללא הגבלה',
                      items: const [
                        DropdownMenuItem(
                            value: 'ללא הגבלה', child: Text('ללא הגבלה')),
                        DropdownMenuItem(
                            value: '1200-1600', child: Text('1,200 - 1,600')),
                        DropdownMenuItem(
                            value: '1600-2000', child: Text('1,600 - 2,000')),
                        DropdownMenuItem(value: '2000+', child: Text('2,000+')),
                      ],
                      onChanged: (v) => setState(() => _draft = v == 'ללא הגבלה'
                          ? _draft.copyWith(clearEngine: true)
                          : _draft.copyWith(engineRange: v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Dropdown<String>(
                      label: 'מספר מקומות',
                      value: _draft.minSeats?.toString() ?? 'הכל',
                      items: const [
                        DropdownMenuItem(value: 'הכל', child: Text('הכל')),
                        DropdownMenuItem(value: '5', child: Text('5 מקומות')),
                        DropdownMenuItem(value: '7', child: Text('7 מקומות')),
                        DropdownMenuItem(value: '8', child: Text('8+ מקומות')),
                      ],
                      onChanged: (v) => setState(() => _draft = v == 'הכל'
                          ? _draft.copyWith(clearSeats: true)
                          : _draft.copyWith(minSeats: int.parse(v!))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _PillGroup(
                label: 'סוג מנוע',
                options: const ['הכל', 'בנזין', 'דיזל', 'היברידי', 'חשמלי'],
                selected: _draft.fuel ?? 'הכל',
                onSelect: (v) => setState(() => _draft = v == 'הכל'
                    ? _draft.copyWith(clearFuel: true)
                    : _draft.copyWith(fuel: v)),
              ),
              const SizedBox(height: 16),

              // Drivetrain, from the models dataset ("hanaa_nm").
              _PillGroup(
                label: 'הנעה',
                options: const ['הכל', '4X2', '4X4'],
                selected: _draft.drivetrain ?? 'הכל',
                onSelect: (v) => setState(() => _draft = v == 'הכל'
                    ? _draft.copyWith(clearDrivetrain: true)
                    : _draft.copyWith(drivetrain: v)),
              ),
              const SizedBox(height: 18),

              _Dropdown<String?>(
                label: 'אזור',
                value: _draft.area,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('כל האזורים')),
                  for (final a in _areas)
                    DropdownMenuItem(value: a, child: Text(a)),
                ],
                onChanged: (v) => setState(() => _draft = v == null
                    ? _draft.copyWith(clearArea: true)
                    : _draft.copyWith(area: v)),
              ),
              const SizedBox(height: 18),

              // Typed at BOTH ends. A slider only ever set a ceiling, and a
              // buyer thinks in ranges — "between 2018 and 2022", not
              // "anything after 2018" — and knows their exact number.
              _range(
                title: 'מחיר',
                from: _priceMinCtl,
                to: _priceMaxCtl,
                fromHint: 'מ-',
                toHint: 'עד',
                suffix: '₪',
              ),
              _range(
                title: 'שנת ייצור',
                from: _yearMinCtl,
                to: _yearMaxCtl,
                fromHint: 'משנת',
                toHint: 'עד שנת',
                suffix: '',
              ),
              _range(
                title: 'קילומטראז\'',
                from: _kmMinCtl,
                to: _kmMaxCtl,
                fromHint: 'מ-',
                toHint: 'עד',
                suffix: 'ק"מ',
              ),
              const SizedBox(height: 8),

              const _SectionLabel('צבע רכב'),
              const SizedBox(height: 10),
              _ColorDots(
                selected: _draft.colorCat == null
                    ? -1
                    : _colorCats.indexOf(_draft.colorCat!),
                onSelect: (i) => setState(() => _draft =
                    _draft.colorCat == _colorCats[i]
                        ? _draft.copyWith(clearColor: true)
                        : _draft.copyWith(colorCat: _colorCats[i])),
              ),
              const SizedBox(height: 8),

            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.tealFill,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: () {
                  ref.read(carFiltersProvider.notifier).state = _draft;
                  Navigator.of(context).pop();
                },
                child: Text('הצג תוצאות ($count רכבים)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// One range, typed at both ends.
  ///
  /// The sliders these replace could only ever set a ceiling, and only in the
  /// steps the track happened to have. Someone whose budget is exactly 85,000
  /// could not land on it, and nobody could say "between 2018 and 2022" at all.
  Widget _range({
    required String title,
    required TextEditingController from,
    required TextEditingController to,
    required String fromHint,
    required String toHint,
    required String suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(title),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _numberField(from, hint: fromHint, suffix: suffix),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                child: Text('—', style: context.text.caption),
              ),
              Expanded(
                child: _numberField(to, hint: toHint, suffix: suffix),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numberField(
    TextEditingController c, {
    required String hint,
    required String suffix,
  }) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      // Numbers read left to right even inside an RTL sheet.
      textDirection: TextDirection.ltr,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(7),
      ],
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        isDense: true,
        // An empty side means "no bound", which is an answer — so it says so
        // rather than sitting there looking unfinished.
        hintText: hint,
        hintStyle: context.text.micro,
        suffixText: suffix.isEmpty ? null : suffix,
        suffixStyle: context.text.micro,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: context.colors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: context.colors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: context.colors.teal, width: 1.5),
        ),
      ),
    );
  }
}

// ---------------- Reusable pieces ----------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: context.colors.textPrimary));
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: context.colors.tealLight,
        foregroundColor: context.colors.tealText,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: onTap,
      child: const Text('נקה הכל', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: const InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _PillGroup extends StatelessWidget {
  const _PillGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
  });
  final String label;
  final List<String> options;
  final String selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.colors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.cardBorder),
          ),
          child: Row(
            children: [
              for (final o in options)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onSelect(o),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected == o
                            ? context.colors.teal
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        o,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: selected == o
                              ? context.colors.onBrand
                              : context.colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorDots extends StatelessWidget {
  const _ColorDots({required this.selected, required this.onSelect});
  final int selected;
  final void Function(int) onSelect;

  /// Swatches, in the same order as the labels in `_colorCats`. Silver and
  /// grey are separate: both are everywhere on Israeli roads, and someone who
  /// wants silver does not mean grey.
  static const _colors = [
    Color(0xFFFFFFFF), // לבן
    Color(0xFF111111), // שחור
    Color(0xFFC8CDD2), // כסף
    Color(0xFF6B7280), // אפור
    Color(0xFF2B6CB0), // כחול
    Color(0xFFC53030), // אדום
    Color(0xFF2F7A4D), // ירוק
    Color(0xFF8A6134), // חום
    Color(0xFFD9A520), // צהוב
  ];

  @override
  Widget build(BuildContext context) {
    // Wrap, not Row: nine 30px dots do not fit one line on a phone, and a Row
    // would silently overflow rather than move to a second line.
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < _colors.length; i++)
          Semantics(
            selected: selected == i,
            button: true,
            label: _colorNames[i],
            child: Tooltip(
              message: _colorNames[i],
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _colors[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected == i
                          ? context.colors.teal
                          : context.colors.cardBorder,
                      width: selected == i ? 3 : 1.5,
                    ),
                  ),
                  // The ring alone carries selection on a dot, and on the
                  // white swatch a green ring on white is easy to miss — the
                  // tick makes the state readable on every colour.
                  child: selected == i
                      ? Icon(Icons.check,
                          size: 16,
                          color: _isDark(_colors[i])
                              ? Colors.white
                              : const Color(0xFF111111))
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static bool _isDark(Color c) => c.computeLuminance() < 0.5;

  static const _colorNames = [
    'לבן',
    'שחור',
    'כסף',
    'אפור',
    'כחול',
    'אדום',
    'ירוק',
    'חום',
    'צהוב',
  ];
}

