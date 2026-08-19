import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/models/gov_data_model.dart';
import '../../providers/cars_provider.dart';
import '../../providers/create_listing_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/seller_verification_provider.dart';
import '../../widgets/primary_button_widget.dart';
import '../../widgets/app_card.dart';
import '../../widgets/step_progress_widget.dart';
import '../../../core/theme/app_text.dart';

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
        onDocument: () async {
          final repo = ref.read(carRepositoryProvider);
          final published = await repo.getCarById(state.publishedId!);
          if (published == null) return;
          final vehicleId =
              await ref.read(documentListingProvider)(published);
          if (vehicleId == null || !context.mounted) return;
          ref.read(createListingControllerProvider.notifier).reset();
          context.go('/vehicle/$vehicleId');
        },
      );
    }

    if (car == null) return const _NeedVerification();

    return Scaffold(
      appBar: AppBar(
        title: const Text('פרסום מודעה'),
        leading: state.step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
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
                // h3 across all three steps. The step bar above already says
                // where you are; the title does not also need to shout.
                const Text('הוסף תמונות של הרכב', style: AppText.h3),
                const SizedBox(height: 4),
                Text(
                  AppConfig.storageEnabled
                      ? 'עד 12 תמונות. הראשונה תשמש כתמונת השער.'
                      // Said here rather than discovered after publishing. The
                      // upload has been failing silently since before the
                      // passport work: the listing went up photoless and
                      // nobody was told why.
                      : 'העלאת תמונות אינה זמינה כרגע. אפשר לפרסם את המודעה '
                          'ולהוסיף תמונות כשהיא תיפתח.',
                  style: TextStyle(color: context.colors.textMuted),
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
          color: context.colors.tealLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.teal),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: context.colors.teal),
            const SizedBox(height: 4),
            Text('הוסף', style: TextStyle(color: context.colors.tealText2, fontSize: 12.5)),
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
                return Container(color: context.colors.cardBorder);
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
                color: context.colors.tealDark.withValues(alpha: 0.8),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'שער',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.onBrand, fontSize: 11.5),
                ),
              ),
            ),
          Positioned(
            top: 2,
            left: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 14, color: context.colors.onBrand),
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
                // Step 2 was the only step without a title, so the flow read
                // as "add photos" → a form with no name → "review".
                const Text('פרטי הרכב', style: AppText.h3),
                const SizedBox(height: 12),
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
        color: context.colors.tealLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: context.colors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  car.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: context.colors.tealText,
                  ),
                ),
                Text(
                  '${car.year} · ${car.fuelType} · אומת מול משרד התחבורה',
                  style:
                      TextStyle(fontSize: 12.5, color: context.colors.tealText2),
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
                const Text('סקירה ואישור', style: AppText.h3),
                const SizedBox(height: 12),
                // One card with hairlines between the rows, rather than eight
                // free-floating lines. A summary is a single object — this is
                // the last thing the seller reads before publishing, and it
                // should look like a document, not a list of leftovers.
                AppCard(
                  padding: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (i, (label, value)) in <(String, String)>[
                        ('רכב', car.title),
                        ('שנה', '${car.year}'),
                        ('מחיר',
                            '₪${_fmt.format(double.tryParse(s.price) ?? 0)}'),
                        ('קילומטראז\'',
                            '${_fmt.format(int.tryParse(s.km) ?? 0)} ק"מ'),
                        ('אזור', s.area),
                        ('תמונות', '${s.photos.length}'),
                        if (s.description.isNotEmpty)
                          ('על הרכב', s.description),
                        if (s.reason.isNotEmpty)
                          ('סיבת המכירה', s.reason),
                      ].indexed) ...[
                        if (i > 0)
                          Divider(
                              height: 1,
                              thickness: 1,
                              color: context.colors.cardBorder),
                        _reviewRow(context, label, value),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.tealLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: context.colors.teal, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'תג "נתונים ממרשם הרכב" והסיווג שבחרת יוצגו במודעה',
                          style: TextStyle(
                              color: context.colors.tealText2, fontSize: 13),
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
                      color: context.colors.errorBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(s.error!,
                        style: TextStyle(color: context.colors.errorRed)),
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
          onPressed: () async {
            // A reading below the last official test is usually a typo and
            // occasionally worse. Either way the seller gets to see the two
            // numbers before the listing goes out.
            final warning = notifier.kmWarning;
            if (warning != null &&
                !await _confirmKm(context, warning)) {
              return;
            }
            notifier.publish();
          },
        ),
      ],
    );
  }

  /// Shows the mismatch and asks whether to go ahead. Returns false if the
  /// seller backs out to fix the number.
  Future<bool> _confirmKm(BuildContext context, String warning) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.speed, color: dialogContext.colors.warnText),
        title: const Text('לבדוק את הקילומטראז\''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(warning, style: AppText.body),
            const SizedBox(height: 12),
            Text(
              'ייתכן שזו טעות הקלדה. אם המספר נכון — למשל לאחר החלפת מד-אוץ — '
              'אפשר להמשיך, וההפרש יוצג לקונים לצד הנתון הרשמי.',
              style: dialogContext.text.bodySmMuted,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('חזרה לתיקון'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('המספר נכון, פרסם'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Widget _reviewRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // No colon: the divider and the alignment already separate the two,
          // and eight colons down a card is visual noise.
          SizedBox(
            width: 92,
            child: Text(label, style: context.text.caption),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppText.bodySm.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Success ----------------

class _PublishedScreen extends StatefulWidget {
  const _PublishedScreen({required this.onDone, required this.onDocument});
  final VoidCallback onDone;
  final Future<void> Function() onDocument;

  @override
  State<_PublishedScreen> createState() => _PublishedScreenState();
}

class _PublishedScreenState extends State<_PublishedScreen> {
  bool _working = false;

  Future<void> _document() async {
    setState(() => _working = true);
    await widget.onDocument();
    if (mounted) setState(() => _working = false);
  }

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
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: context.colors.tealLight,
                  shape: BoxShape.circle,
                ),
                // The bare mark, not `check_circle` — a filled ring inside a
                // filled ring was two circles saying the same thing.
                child: Icon(Icons.check,
                    size: 34, color: context.colors.tealText),
              ),
              const SizedBox(height: 20),
              const Text('המודעה פורסמה!', style: AppText.h2),
              const SizedBox(height: 8),
              Text(
                'הרכב שלך זמין כעת לקונים ב-BonnetCheck',
                textAlign: TextAlign.center,
                style: context.text.bodySmMuted,
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: _Stat(label: 'צפיות', value: '0')),
                  SizedBox(width: 10),
                  Expanded(child: _Stat(label: 'שמירות', value: '0')),
                  SizedBox(width: 10),
                  Expanded(child: _Stat(label: 'הודעות', value: '0')),
                ],
              ),
              const SizedBox(height: 32),
              // Offered here rather than buried in the passport, because this
              // is the moment a seller is thinking about what makes their car
              // worth the asking price — and a documented history is the one
              // thing on the listing they can still add to.
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'תעדו את הטיפולים שעשיתם',
                  loading: _working,
                  onPressed: _document,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'קונים רואים רכב מתועד אחרת. אפשר גם מאוחר יותר.',
                textAlign: TextAlign.center,
                style: context.text.caption,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _working ? null : widget.onDone,
                  child: const Text('למודעה שלי'),
                ),
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
    // A bordered tile rather than a bare number, so three zeros on a blank
    // screen read as counters waiting to move rather than as an error.
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(value, style: AppText.h3),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.micro),
        ],
      ),
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
                Icon(Icons.verified_user_outlined,
                    size: 64, color: context.colors.textSubtle),
                const SizedBox(height: 12),
                Text(
                  'יש להשלים אימות מוכר לפני פרסום מודעה',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textMuted),
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
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.cardBorder)),
      ),
      child: PrimaryButton(
        label: label,
        loading: loading,
        onPressed: onPressed,
      ),
    );
  }
}
