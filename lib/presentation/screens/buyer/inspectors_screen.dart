import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/inspection_center.dart';
import '../../providers/cars_provider.dart';
import '../../providers/gov_api_provider.dart';

/// Directory of licensed pre-purchase inspection centers ("מכוני בדיקה"),
/// straight from official Ministry of Transport data. The buyer finds one near
/// the car's city, then calls or navigates there. Opened from the car page.
class InspectorsScreen extends ConsumerStatefulWidget {
  const InspectorsScreen({super.key, required this.carId});

  final String carId;

  @override
  ConsumerState<InspectorsScreen> createState() => _InspectorsScreenState();
}

class _InspectorsScreenState extends ConsumerState<InspectorsScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Prefill with the listing's city so nearby centers surface first (the
    // car page usually already has it cached).
    final area =
        ref.read(carByIdProvider(widget.carId)).valueOrNull?.area.trim() ?? '';
    if (area.isNotEmpty) {
      _controller.text = area;
      _query = area;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<InspectionCenter> _filter(List<InspectionCenter> all) {
    final q = _query.trim();
    if (q.isEmpty) return all;
    return all
        .where((c) =>
            c.name.contains(q) ||
            c.city.contains(q) ||
            c.address.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final centersAsync = ref.watch(inspectionCentersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('מכוני בדיקת רכב')),
      body: SafeArea(
        child: Column(
          children: [
            _Header(controller: _controller, onChanged: (v) {
              setState(() => _query = v);
            }),
            Expanded(
              child: centersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const _Message(
                    icon: Icons.cloud_off,
                    text: 'לא ניתן לטעון את רשימת המכונים כרגע.\nבדקו את החיבור ונסו שוב.'),
                data: (all) {
                  final list = _filter(all);
                  if (list.isEmpty) {
                    return _Message(
                      icon: Icons.search_off,
                      text: _query.trim().isEmpty
                          ? 'לא נמצאו מכונים.'
                          : 'לא נמצאו מכונים לחיפוש "${_query.trim()}".',
                      actionLabel: _query.trim().isEmpty ? null : 'הצג הכל',
                      onAction: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: list.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10, top: 2),
                          child: Text(
                            '${list.length} מכונים מורשים · מקור: משרד התחבורה',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSubtle),
                          ),
                        );
                      }
                      return _CenterCard(center: list[i - 1]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'קחו את הרכב לבדיקה לפני קנייה במכון מורשה. הרשימה הרשמית של משרד התחבורה.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'חיפוש לפי עיר או שם מכון…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterCard extends StatelessWidget {
  const _CenterCard({required this.center});
  final InspectionCenter center;

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא ניתן לפתוח את הפעולה')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.tealLight,
                child: Icon(Icons.build_circle_outlined,
                    color: AppColors.teal, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(center.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.textSubtle),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(center.fullAddress,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (center.hasPhone)
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        minimumSize: const Size.fromHeight(44)),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('התקשר'),
                    onPressed: () => _launch(
                        context, Uri.parse('tel:${center.phoneDigits}')),
                  ),
                ),
              if (center.hasPhone) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    side: const BorderSide(color: AppColors.teal),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text('ניווט'),
                  onPressed: () => _launch(
                    context,
                    Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(center.mapsQuery)}'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textSubtle),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted)),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
