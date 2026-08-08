import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  static final _fmt = NumberFormat('#,###', 'en');

  late CarFilters _draft;

  static const _colorCats = ['לבן', 'שחור', 'אפור', 'כחול', 'אדום'];


  @override
  void initState() {
    super.initState();
    _draft = ref.read(carFiltersProvider);
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
    if (c.price > f.maxPrice) return false;
    if (c.year < f.minYear) return false;
    if (c.km > f.maxKm) return false;
    if (f.area != null && c.area != f.area) return false;
    if (query.isNotEmpty) {
      final hay = '${c.make} ${c.model} ${c.area} ${c.plate}'.toLowerCase();
      if (!hay.contains(query.toLowerCase())) return false;
    }
    return true;
  }

  void _clearAll() {
    setState(() {
      _draft = const CarFilters();
    });
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

              // Buy range sliders (functional).
              _slider(
                title: 'מחיר עד',
                value: _draft.maxPrice,
                min: 30000,
                max: CarFilters.priceCap,
                divisions: 47,
                display: _draft.maxPrice >= CarFilters.priceCap
                    ? 'ללא הגבלה'
                    : '₪${_fmt.format(_draft.maxPrice)}',
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(maxPrice: v)),
              ),
              _slider(
                title: 'שנת ייצור מ-',
                value: _draft.minYear.toDouble(),
                min: CarFilters.yearFloor.toDouble(),
                max: 2025,
                divisions: 2025 - CarFilters.yearFloor,
                display: '${_draft.minYear}',
                onChanged: (v) => setState(
                    () => _draft = _draft.copyWith(minYear: v.round())),
              ),
              _slider(
                title: 'קילומטראז\' עד',
                value: _draft.maxKm.toDouble(),
                min: 0,
                max: CarFilters.kmCap.toDouble(),
                divisions: 40,
                display: _draft.maxKm >= CarFilters.kmCap
                    ? 'ללא הגבלה'
                    : '${_fmt.format(_draft.maxKm)} ק"מ',
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(maxKm: v.round())),
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

  Widget _slider({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _SectionLabel(title)),
              Text(display,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: context.colors.teal)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: context.colors.teal,
            onChanged: onChanged,
          ),
        ],
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

  static const _colors = [
    Color(0xFFFFFFFF),
    Color(0xFF111111),
    Color(0xFFA0AEC0),
    Color(0xFF2B6CB0),
    Color(0xFFC53030),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _colors.length; i++)
          GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              margin: const EdgeInsets.only(left: 10),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _colors[i],
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == i ? context.colors.teal : context.colors.cardBorder,
                  width: selected == i ? 2.5 : 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

