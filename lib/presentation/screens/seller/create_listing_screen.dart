import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/gov_data_model.dart';
import '../../providers/create_listing_provider.dart';
import '../../providers/seller_verification_provider.dart';
import '../../widgets/primary_button_widget.dart';
import '../../widgets/step_progress_widget.dart';

class CreateListingScreen extends ConsumerWidget {
  const CreateListingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createListingControllerProvider);
    final car = ref.watch(sellerVerificationControllerProvider).carData;

    // Once published, show the success screen.
    if (state.publishedId != null) {
      return _PublishedScreen(
        onDone: () {
          ref.read(createListingControllerProvider.notifier).reset();
          context.go('/seller/listing');
        },
      );
    }

    if (car == null) return const _NeedVerification();

    return Scaffold(
      appBar: AppBar(
        title: const Text('פרסום מודעה'),
        leading: state.step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () =>
                    ref.read(createListingControllerProvider.notifier).back(),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: StepProgress(current: state.step + 1),
            ),
            Expanded(
              child: switch (state.step) {
                0 => const _StepPhotos(),
                1 => _StepDetails(car: car),
                _ => _StepReview(car: car),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Step 1: Photos ----------------

class _StepPhotos extends ConsumerWidget {
  const _StepPhotos();

  Future<void> _pick(WidgetRef ref) async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 70);
    if (picked.isNotEmpty) {
      ref.read(createListingControllerProvider.notifier).addPhotos(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(createListingControllerProvider).photos;
    final notifier = ref.read(createListingControllerProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'הוסף תמונות של הרכב',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'עד 12 תמונות. הראשונה תשמש כתמונת השער.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: photos.length + 1,
                    itemBuilder: (context, i) {
                      if (i == photos.length) {
                        return _AddTile(onTap: () => _pick(ref));
                      }
                      return _PhotoThumb(
                        file: photos[i],
                        isCover: i == 0,
                        onRemove: () => notifier.removePhoto(i),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        _BottomBar(
          label: 'המשך',
          onPressed: photos.isNotEmpty ? () => notifier.next() : null,
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.tealLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.teal),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.teal),
            SizedBox(height: 4),
            Text('הוסף', style: TextStyle(color: AppColors.teal, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.file,
    required this.isCover,
    required this.onRemove,
  });

  final XFile file;
  final bool isCover;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return Container(color: AppColors.cardBorder);
              }
              return Image.memory(snap.data!, fit: BoxFit.cover);
            },
          ),
          if (isCover)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: AppColors.tealDark.withValues(alpha: 0.8),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Text(
                  'שער',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.white, fontSize: 11),
                ),
              ),
            ),
          Positioned(
            top: 2,
            left: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 14, color: AppColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Step 2: Details ----------------

class _StepDetails extends ConsumerStatefulWidget {
  const _StepDetails({required this.car});
  final GovData car;

  @override
  ConsumerState<_StepDetails> createState() => _StepDetailsState();
}

class _StepDetailsState extends ConsumerState<_StepDetails> {
  late final TextEditingController _price;
  late final TextEditingController _km;
  late final TextEditingController _reason;
  late final TextEditingController _description;

  static const _areas = [
    'תל אביב', 'ירושלים', 'חיפה', 'ראשון לציון', 'פתח תקווה',
    'באר שבע', 'נתניה', 'אשדוד', 'רמת גן', 'הרצליה', 'אחר',
  ];
  String? _area;

  @override
  void initState() {
    super.initState();
    final s = ref.read(createListingControllerProvider);
    _price = TextEditingController(text: s.price);
    _km = TextEditingController(text: s.km);
    _reason = TextEditingController(text: s.reason);
    _description = TextEditingController(text: s.description);
    _area = s.area.isEmpty ? null : s.area;
  }

  @override
  void dispose() {
    _price.dispose();
    _km.dispose();
    _reason.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(createListingControllerProvider.notifier);
    final car = widget.car;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReadOnlyCarCard(car: car),
                const SizedBox(height: 16),
                TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (v) {
                    notifier.setPrice(v);
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: 'מחיר (₪)',
                    hintText: '95000',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _km,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (v) {
                    notifier.setKm(v);
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: 'קילומטראז\'',
                    hintText: '45000',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _area,
                  decoration: const InputDecoration(labelText: 'אזור'),
                  items: [
                    for (final a in _areas)
                      DropdownMenuItem(value: a, child: Text(a)),
                  ],
                  onChanged: (v) {
                    setState(() => _area = v);
                    notifier.setArea(v ?? '');
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLines: 4,
                  maxLength: 600,
                  onChanged: notifier.setDescription,
                  decoration: const InputDecoration(
                    labelText: 'כמה מילים על הרכב',
                    hintText:
                        'למשל: רכב שמור, טופל תמיד במוסך מורשה, ללא תאונות, צמיגים חדשים…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reason,
                  maxLines: 3,
                  onChanged: notifier.setReason,
                  decoration: const InputDecoration(
                    labelText: 'סיבת המכירה',
                    hintText: 'למשל: עוברים לרכב גדול יותר',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        _BottomBar(
          label: 'המשך',
          onPressed: notifier.detailsValid ? () => notifier.next() : null,
        ),
      ],
    );
  }
}

class _ReadOnlyCarCard extends StatelessWidget {
  const _ReadOnlyCarCard({required this.car});
  final GovData car;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  car.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.tealText,
                  ),
                ),
                Text(
                  '${car.year} · ${car.fuelType} · אומת מול משרד התחבורה',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.tealText2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Step 3: Review ----------------

class _StepReview extends ConsumerWidget {
  const _StepReview({required this.car});
  final GovData car;

  static final _fmt = NumberFormat('#,###', 'en');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(createListingControllerProvider);
    final notifier = ref.read(createListingControllerProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'סקירה ואישור',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _reviewRow('רכב', car.title),
                _reviewRow('שנה', '${car.year}'),
                _reviewRow('מחיר',
                    '₪${_fmt.format(double.tryParse(s.price) ?? 0)}'),
                _reviewRow('קילומטראז\'',
                    '${_fmt.format(int.tryParse(s.km) ?? 0)} ק"מ'),
                _reviewRow('אזור', s.area),
                _reviewRow('תמונות', '${s.photos.length}'),
                if (s.description.isNotEmpty)
                  _reviewRow('על הרכב', s.description),
                if (s.reason.isNotEmpty) _reviewRow('סיבת המכירה', s.reason),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified, color: AppColors.teal, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'תג "מוכר מאומת" יוצג אוטומטית במודעה שלך',
                          style: TextStyle(
                              color: AppColors.tealText2, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                if (s.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(s.error!,
                        style: const TextStyle(color: AppColors.errorRed)),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        _BottomBar(
          label: 'פרסם מודעה',
          loading: s.publishing,
          onPressed: () => notifier.publish(),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text('$label:',
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Success ----------------

class _PublishedScreen extends StatelessWidget {
  const _PublishedScreen({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  color: AppColors.tealLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    size: 60, color: AppColors.teal),
              ),
              const SizedBox(height: 20),
              const Text(
                'המודעה פורסמה!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'הרכב שלך זמין כעת לקונים ב-AutoProof',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Stat(label: 'צפיות', value: '0'),
                  _Stat(label: 'שמירות', value: '0'),
                  _Stat(label: 'הודעות', value: '0'),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(label: 'למודעה שלי', onPressed: onDone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.teal)),
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ],
    );
  }
}

class _NeedVerification extends StatelessWidget {
  const _NeedVerification();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('פרסום מודעה')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user_outlined,
                    size: 64, color: AppColors.textSubtle),
                const SizedBox(height: 12),
                const Text(
                  'יש לאמת שאתה בעלים פרטי לפני פרסום מודעה',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'לאימות מוכר',
                  onPressed: () => context.go('/verify/role'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Shared bottom bar ----------------

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: PrimaryButton(
        label: label,
        loading: loading,
        onPressed: onPressed,
      ),
    );
  }
}
