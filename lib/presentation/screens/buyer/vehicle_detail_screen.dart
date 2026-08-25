import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/document_redactor.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/service_record.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_document.dart';
import '../../../data/models/vehicle_reminder.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/add_reminder_sheet.dart';
import '../../widgets/app_card.dart';
import '../../widgets/plate_text.dart';
import '../../widgets/documented_progress_meter.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/document_list.dart';
import '../../widgets/expense_summary.dart';
import '../../widgets/garage/my_garages_section.dart';
import '../../widgets/garage/nearby_washes_section.dart';
import 'redact_document_screen.dart';
import '../../widgets/primary_button_widget.dart';
import '../../widgets/service_timeline.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/spec_tile.dart';
import 'add_expense_screen.dart';
import 'add_service_screen.dart';

/// The passport itself — one car, everything known about it.
///
/// Tabs are added as the features that fill them land. A tab opening onto
/// "coming soon" is worse than a tab that is not there yet.
class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleProvider(vehicleId));

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            vehicleAsync.valueOrNull?.nickname.trim().isNotEmpty == true
                ? vehicleAsync.value!.nickname.trim()
                : 'הרכב שלי',
          ),
          actions: [
            // Listed cars get "sold" instead of "publish" — the next thing an
            // owner does to a car that is already on the market is close it.
            if (vehicleAsync.valueOrNull != null)
              TextButton(
                onPressed: () => context.push(
                  vehicleAsync.value!.isListed
                      ? '/vehicle/$vehicleId/sell'
                      : '/vehicle/$vehicleId/publish',
                ),
                child: Text(
                  vehicleAsync.value!.isListed ? 'סמן כנמכר' : 'פרסם למכירה',
                ),
              ),
            if (vehicleAsync.valueOrNull != null)
              _VehicleMenu(vehicle: vehicleAsync.value!),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'סקירה'),
              Tab(text: 'טיפולים'),
              Tab(text: 'הוצאות'),
              Tab(text: 'מסמכים'),
            ],
          ),
        ),
        body: SafeArea(
          child: vehicleAsync.when(
            loading: () => const _DetailSkeleton(),
            error: (_, __) => ErrorRetry(
              message: 'לא הצלחנו לטעון את הרכב',
              onRetry: () => ref.invalidate(vehicleProvider(vehicleId)),
            ),
            data: (vehicle) => vehicle == null
                ? const _Message('הרכב לא נמצא')
                : TabBarView(
                    children: [
                      _Overview(vehicle: vehicle),
                      _ServicesTab(vehicle: vehicle),
                      _ExpensesTab(vehicle: vehicle),
                      _DocumentsTab(vehicle: vehicle),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Removing a car from the garage.
///
/// Only possible while it holds no service records, which is the same rule the
/// security rules enforce. Rather than hiding the action once records exist,
/// it explains why: "delete and re-add" would otherwise be an eraser, and the
/// moment someone reaches for it is exactly the moment worth saying so.
class _VehicleMenu extends ConsumerWidget {
  const _VehicleMenu({required this.vehicle});

  final Vehicle vehicle;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (vehicle.serviceCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('לא ניתן להסיר את הרכב'),
          content: Text(
            'לרכב יש ${vehicle.serviceCount} רשומות טיפול, ורשומות טיפול לא '
            'נמחקות לעולם. אם אפשר היה להסיר רכב ולהוסיף אותו מחדש, זו הייתה '
            'דרך למחוק היסטוריה — וכל התיק היה מאבד את ערכו.\n\n'
            'אם מכרתם את הרכב, השתמשו ב"סמן כנמכר".',
            style: AppText.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('הבנתי'),
            ),
          ],
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('להסיר את הרכב?'),
        content: const Text(
          'הרכב יוסר מהרשימה שלכם. אין בו רשומות טיפול, אז לא הולך לאיבוד '
          'תיעוד.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('הסר'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(vehicleRepositoryProvider).deleteEmptyVehicle(vehicle.id);
      if (context.mounted) context.go('/garage');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא הצלחנו להסיר את הרכב')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'עוד',
      onSelected: (value) {
        if (value == 'delete') _delete(context, ref);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'delete', child: Text('הסר רכב')),
      ],
    );
  }
}

/// The history, and the one button that can change it.
class _ServicesTab extends ConsumerWidget {
  const _ServicesTab({required this.vehicle});

  final Vehicle vehicle;

  Future<void> _add(BuildContext context,
      {String? corrects, ServiceRecord? editing}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddServiceScreen(
          vehicleId: vehicle.id,
          correctsServiceId: corrects,
          editing: editing,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(vehicleServicesProvider(vehicle.id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('הוסף טיפול'),
      ),
      body: servicesAsync.when(
        loading: () => const _DetailSkeleton(),
        error: (_, __) => ErrorRetry(
          compact: true,
          message: 'לא הצלחנו לטעון את הטיפולים',
          onRetry: () => ref.invalidate(vehicleServicesProvider(vehicle.id)),
        ),
        data: (records) => records.isEmpty
            ? _EmptyServices(onAdd: () => _add(context))
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.lg,
                  AppSpace.lg,
                  96, // clears the floating button
                ),
                children: [
                  if (!vehicle.hasDocumentedHistory)
                    DocumentedProgressMeter(
                      progress: vehicle.documentedProgress,
                    ),
                  ServiceTimeline(
                    records: records,
                    // "הוסף תיקון" is gone from the row: since 25/08 the
                    // owner edits the record itself. The correction path
                    // stays in the model and the repository for the entries
                    // written while it was the only way to fix one.
                    onEdit: (r) => _add(context, editing: r),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The wallet: what the car costs to run, month by month.
class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab({required this.vehicle});

  final Vehicle vehicle;

  Future<void> _open(BuildContext context, {Expense? existing}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          vehicleId: vehicle.id,
          existing: existing,
        ),
      ),
    );
  }

  /// Deleting an expense is instant and cannot be undone, and the bin sits a
  /// thumb's width from the row you tap to edit. Documents already ask before
  /// deleting; this asks too, rather than being the one place a mis-tap costs
  /// you data.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('למחוק את ההוצאה?'),
        content: Text(
          '${expense.displayTitle} · ${expense.amount} ₪',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('מחק'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(expenseActionsProvider).remove(vehicle.id, expense.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(vehicleExpensesProvider(vehicle.id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context),
        icon: const Icon(Icons.add),
        label: const Text('הוסף הוצאה'),
      ),
      body: expensesAsync.when(
        loading: () => const _DetailSkeleton(),
        error: (_, __) => ErrorRetry(
          compact: true,
          message: 'לא הצלחנו לטעון את ההוצאות',
          onRetry: () => ref.invalidate(vehicleExpensesProvider(vehicle.id)),
        ),
        data: (expenses) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.lg,
            AppSpace.lg,
            96,
          ),
          children: [
            ExpenseSummary(expenses: expenses),
            const SizedBox(height: AppSpace.xl),
            if (expenses.isEmpty)
              Text(
                'רשמו תדלוק, ניקיון או חניה — וכאן תראו כמה הרכב באמת עולה '
                'לכם בחודש. ההוצאות פרטיות ולא מוצגות לקונים.',
                style: context.text.bodyMuted,
              )
            else
              for (final month in ExpenseMonth.group(expenses)) ...[
                _MonthHeader(month: month),
                for (final e in expenses.where((x) =>
                    x.date.year == month.year && x.date.month == month.month))
                  _ExpenseRow(
                    expense: e,
                    onEdit: () => _open(context, existing: e),
                    onDelete: () => _confirmDelete(context, ref, e),
                  ),
                const SizedBox(height: AppSpace.lg),
              ],
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month});

  final ExpenseMonth month;

  static const _names = [
    'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
    'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר',
  ];

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_names[month.month - 1]} ${month.year}',
                style: AppText.subtitle,
              ),
            ),
            Text('${_thousands(month.total)} ₪', style: context.text.caption),
          ],
        ),
      );
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final perLitre = expense.pricePerLitre;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.md),
        onTap: onEdit,
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: ExpenseSummary.colorFor(expense.type, context),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.displayTitle, style: AppText.bodySm),
                  Text(
                    [
                      '${expense.date.day}/${expense.date.month}',
                      if (perLitre != null)
                        '${perLitre.toStringAsFixed(2)} ₪ לליטר',
                    ].join(' · '),
                    style: context.text.caption,
                  ),
                ],
              ),
            ),
            Text('${_thousands(expense.amount)} ₪', style: AppText.bodySm),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'מחק',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// The filing cabinet.
class _DocumentsTab extends ConsumerStatefulWidget {
  const _DocumentsTab({required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends ConsumerState<_DocumentsTab> {
  bool _uploading = false;

  Future<void> _add() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;

    final type = await showModalBottomSheet<DocumentType>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: Text('איזה מסמך זה?', style: AppText.subtitle),
            ),
            for (final t in DocumentType.values)
              ListTile(
                title: Text(t.label),
                subtitle: t.carriesPersonalData
                    ? const Text('כולל לרוב פרטים אישיים')
                    : null,
                onTap: () => Navigator.of(c).pop(t),
              ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;

    final bytes = await picked.readAsBytes();

    // Reading a phone photo off disk is not instant, and `ref` throws once the
    // widget is gone. The try/catch below would swallow that into "העלאת
    // המסמך נכשלה" and then not even show it — an upload that silently did
    // not happen, which is the exact thing this screen was just fixed to stop
    // doing.
    if (!mounted) return;

    // Nothing reaches the repository without passing through here. The
    // redactor is what strips the EXIF block and burns in whatever the owner
    // painted over, and `DocumentActions.save` takes only its output — so
    // there is no path that stores an original by accident.
    final redacted = await Navigator.of(context).push<RedactedDocument>(
      MaterialPageRoute(
        builder: (_) => RedactDocumentScreen(bytes: bytes, type: type),
      ),
    );
    if (redacted == null || !mounted) return;

    setState(() => _uploading = true);

    try {
      await ref.read(documentActionsProvider).save(
            vehicleId: widget.vehicle.id,
            redacted: redacted,
            type: type,
            title: type.label,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('העלאת המסמך נכשלה')),
        );
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(vehicleDocumentsProvider(widget.vehicle.id));
    final actions = ref.read(documentActionsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // No longer gated on Storage: a document's bytes go into Firestore, so
      // this is the one upload in the app that works without the Blaze plan.
      // Service receipts and listing photos still wait for a bucket.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _add,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file),
        label: Text(_uploading ? 'שומר...' : 'העלה מסמך'),
      ),
      body: docsAsync.when(
        loading: () => const _DetailSkeleton(),
        error: (_, __) => ErrorRetry(
          compact: true,
          message: 'לא הצלחנו לטעון את המסמכים',
          onRetry: () =>
              ref.invalidate(vehicleDocumentsProvider(widget.vehicle.id)),
        ),
        data: (documents) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.lg,
            AppSpace.lg,
            96,
          ),
          children: [
            Text(
              'כל מסמך שתעלו נשמר פרטי. תוכלו לבחור, לכל מסמך בנפרד, '
              'אם להציג אותו לקונים כשהרכב מפורסם למכירה.',
              style: context.text.bodyMuted,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'לפני שמסמך נשמר תוכלו להשחיר בו פרטים — מספר תעודת '
              'זהות, כתובת. מה שתסמנו נמחק מהתמונה עצמה, ונתוני המיקום '
              'של הצילום מוסרים תמיד.',
              style: context.text.micro,
            ),
            const SizedBox(height: AppSpace.lg),
            if (documents.isEmpty)
              Text('עוד לא הועלו מסמכים', style: context.text.caption)
            else
              DocumentList(
                vehicleId: widget.vehicle.id,
                documents: documents,
                onToggleShare: (doc, shared) =>
                    actions.setShared(widget.vehicle.id, doc.id, shared),
                onDelete: (doc) => actions.remove(widget.vehicle.id, doc),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyServices extends StatelessWidget {
  const _EmptyServices({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.build_outlined, size: 48, color: context.colors.teal),
            const SizedBox(height: AppSpace.lg),
            const Text('עוד לא תועד כאן טיפול', style: AppText.h3),
            const SizedBox(height: AppSpace.sm),
            Text(
              'כל טיפול שתתעדו נשמר עם התאריך והקילומטראז\'. '
              'אחרי 3 רשומות לאורך חצי שנה הרכב יקבל תג "תיק מתועד", '
              'שיוצג לקונים אם תחליטו למכור.',
              textAlign: TextAlign.center,
              style: context.text.bodyMuted,
            ),
            const SizedBox(height: AppSpace.xl),
            PrimaryButton(label: 'הוסף טיפול ראשון', onPressed: onAdd),
          ],
        ),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gov = vehicle.govSnapshot ?? const {};
    final reminders =
        ref.watch(vehicleRemindersProvider(vehicle.id)).valueOrNull ?? const [];

    final make = '${gov['make'] ?? ''}'.trim();
    final model = '${gov['model'] ?? ''}'.trim();
    final year = gov['year'];

    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [make, model].where((s) => s.isNotEmpty).join(' '),
                style: AppText.h3,
              ),
              const SizedBox(height: AppSpace.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (year != null) ...[
                    Text('$year', style: context.text.caption),
                    Text(' · ', style: context.text.caption),
                  ],
                  // Revealable here and nowhere else: it is the owner's own
                  // car, and they need the number for an insurer or a
                  // transfer. It returns to stars when the screen closes.
                  PlateText(vehicle.plate, revealable: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        const Text('מפרט רשמי', style: AppText.subtitle),
        const SizedBox(height: AppSpace.md),
        // SpecTileGrid, not a Wrap of fixed-width boxes: it pairs the
        // tiles, keeps each row's heights equal, and refuses to stretch a
        // lone tile to full width. A hard-coded width also overflows once
        // the reader turns the system font up.
        SpecTileGrid(tiles: [
          _tile(Icons.speed_outlined, 'קילומטראז\'',
              '${_thousands(vehicle.currentKm)} ק"מ'),
          if ('${gov['fuelType'] ?? ''}'.isNotEmpty)
            _tile(Icons.local_gas_station_outlined, 'סוג דלק',
                '${gov['fuelType']}'),
          if ('${gov['color'] ?? ''}'.isNotEmpty)
            _tile(Icons.palette_outlined, 'צבע', '${gov['color']}'),
          if ('${gov['trim'] ?? ''}'.isNotEmpty)
            _tile(Icons.tune, 'רמת גימור', '${gov['trim']}'),
        ]),
        if (vehicle.openRecallCount > 0) ...[
          const SizedBox(height: AppSpace.lg),
          _RecallBanner(count: vehicle.openRecallCount),
        ],
        const SizedBox(height: AppSpace.xl),
        Row(
          children: [
            const Expanded(child: Text('תזכורות', style: AppText.subtitle)),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('הוסף'),
              onPressed: () => AddReminderSheet.show(context, vehicle.id),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        if (reminders.isEmpty)
          Text(
            'אין תזכורות. תוקף הטסט נוסף אוטומטית כשמוסיפים רכב.',
            style: context.text.caption,
          )
        else
          for (final r in reminders)
            _ReminderRow(
              reminder: r,
              onToggle: (done) => ref
                  .read(vehicleRepositoryProvider)
                  .setReminderDone(vehicle.id, r.id, done),
              onDelete: () => ref
                  .read(vehicleRepositoryProvider)
                  .deleteReminder(vehicle.id, r.id),
            ),
        const SizedBox(height: AppSpace.xl),
        // The garages this car has been to, then the washes anybody can add.
        // Two separate groups with their own headings, never mixed: "somewhere
        // you have been" and "somewhere that exists" are different claims.
        MyGaragesSection(
          vehicleId: vehicle.id,
          services: ref.watch(vehicleServicesProvider(vehicle.id)).valueOrNull ??
              const [],
        ),
        const NearbyWashesSection(),
        Text(
          'הנתונים נמשכו ממרשם כלי הרכב של משרד התחבורה בעת הוספת הרכב. '
          'BonnetCheck אינה מאמתת אותם ואינה מעידה על מצב הרכב.',
          style: context.text.caption,
        ),
      ],
    );
  }

  SpecTile _tile(IconData icon, String label, String value) =>
      SpecTile(icon: icon, label: label, value: value);
}

/// An open service recall from the government dataset.
///
/// The wording is a fact plus what to do about it, never a verdict on the car:
/// an open recall is a repair the manufacturer owes, not evidence the car is
/// unsafe today.
class _RecallBanner extends StatelessWidget {
  const _RecallBanner({required this.count});

  final int count;

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
          Icon(Icons.campaign_outlined, size: 20, color: colors.errorRed),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? 'קריאת שירות פתוחה'
                      : '$count קריאות שירות פתוחות',
                  style: AppText.bodySm.copyWith(
                    color: colors.errorRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'התיקון מבוצע ללא תשלום בסוכנות מורשית.',
                  style: AppText.bodySm.copyWith(color: colors.errorRed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.reminder,
    this.onToggle,
    this.onDelete,
  });

  final VehicleReminder reminder;
  final void Function(bool done)? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = reminder.daysUntilDue;
    final subtitle = days == null
        ? (reminder.dueKm != null ? 'ב-${_thousands(reminder.dueKm!)} ק"מ' : '')
        : days < 0
            ? 'עבר התאריך ב-${days.abs()} ימים'
            : days == 0
                ? 'היום'
                : 'בעוד $days ימים';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(
          children: [
            Icon(
              reminder.isOverdue ? Icons.error_outline : Icons.schedule,
              size: 20,
              color: reminder.isOverdue ? colors.errorRed : colors.teal,
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: AppText.bodySm.copyWith(
                      decoration: reminder.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      color: reminder.isDone ? colors.textMuted : null,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: context.text.caption),
                ],
              ),
            ),
            if (onToggle != null)
              IconButton(
                icon: Icon(
                  reminder.isDone
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: reminder.isDone ? colors.teal : colors.textSubtle,
                ),
                tooltip: reminder.isDone ? 'החזר לפתוח' : 'סמן כבוצע',
                onPressed: () => onToggle!(!reminder.isDone),
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'מחק',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 180, height: 20),
            SizedBox(height: AppSpace.md),
            Skeleton(width: 120),
            SizedBox(height: AppSpace.xl),
            Skeleton(height: 70),
          ],
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Text(text, style: context.text.bodyMuted),
        ),
      );
}


String _thousands(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
