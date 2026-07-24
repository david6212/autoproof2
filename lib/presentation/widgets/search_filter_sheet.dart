import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../providers/cars_provider.dart';
import 'car_type_icon.dart';

/// Opens the buyer filter sheet. Edits a local draft, then commits it to
/// [carFiltersProvider] on "apply".
Future<void> showSearchFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.9,
      child: _FilterSheet(),
    ),
  );
}

const _bodyTypes = ['משפחתי', 'קרוסאובר', 'ספורט', 'חשמלי', 'היברידי'];
const _areas = [
  'תל אביב', 'ירושלים', 'חיפה', 'ראשון לציון', 'פתח תקווה',
  'באר שבע', 'נתניה', 'אשדוד', 'רמת גן', 'הרצליה',
];

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late CarFilters _draft;
  static final _fmt = NumberFormat('#,###', 'en');

  @override
  void initState() {
    super.initState();
    _draft = ref.read(carFiltersProvider);
  }

  void _toggleType(String t) {
    final types = {..._draft.types};
    if (types.contains(t)) {
      types.remove(t);
    } else if (types.length < 4) {
      types.add(t);
    }
    setState(() => _draft = _draft.copyWith(types: types));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.cardBorder,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              const Text('סינון רכבים',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    setState(() => _draft = const CarFilters()),
                child: const Text('נקה הכל'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _label('סוג רכב', hint: 'עד 4'),
              const SizedBox(height: 10),
              _TypeGrid(
                selected: _draft.types,
                onToggle: _toggleType,
              ),
              const SizedBox(height: 24),

              _sliderSection(
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
              _sliderSection(
                title: 'שנת ייצור מ-',
                value: _draft.minYear.toDouble(),
                min: CarFilters.yearFloor.toDouble(),
                max: 2025,
                divisions: 2025 - CarFilters.yearFloor,
                display: '${_draft.minYear}',
                onChanged: (v) => setState(
                    () => _draft = _draft.copyWith(minYear: v.round())),
              ),
              _sliderSection(
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
              const SizedBox(height: 12),
              _label('אזור'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: _draft.area,
                decoration: const InputDecoration(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('כל האזורים')),
                  for (final a in _areas)
                    DropdownMenuItem(value: a, child: Text(a)),
                ],
                onChanged: (v) => setState(() => _draft = v == null
                    ? _draft.copyWith(clearArea: true)
                    : _draft.copyWith(area: v)),
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
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                onPressed: () {
                  ref.read(carFiltersProvider.notifier).state = _draft;
                  Navigator.of(context).pop();
                },
                child: Text(
                  _draft.activeCount == 0
                      ? 'הצג תוצאות'
                      : 'הצג תוצאות · ${_draft.activeCount} מסננים',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text, {String? hint}) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        if (hint != null) ...[
          const SizedBox(width: 6),
          Text('($hint)',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSubtle)),
        ],
      ],
    );
  }

  Widget _sliderSection({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _label(title)),
              Text(display,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.teal)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppColors.teal,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TypeGrid extends StatelessWidget {
  const _TypeGrid({required this.selected, required this.onToggle});
  final Set<String> selected;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final t in _bodyTypes)
          _TypeCard(
            type: t,
            active: selected.contains(t),
            onTap: () => onToggle(t),
          ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard(
      {required this.type, required this.active, required this.onTap});
  final String type;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.teal : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.tealLight : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.teal : AppColors.cardBorder,
            width: active ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            CarTypeIcon(type: type, color: color, width: 62),
            const SizedBox(height: 6),
            Text(type,
                style: TextStyle(
                    color: active ? AppColors.tealText : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
