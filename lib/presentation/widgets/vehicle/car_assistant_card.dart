import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assistant/car_assistant.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/gov_data_model.dart';
import '../../../data/models/service_record.dart';
import '../../../data/models/vehicle.dart';
import '../../providers/vehicle_provider.dart';
import '../app_card.dart';

/// Ask a question about your own car and get an answer from your own data.
///
/// **Nothing here leaves the device.** No API, no key, no cost, and no waiting.
/// [CarAssistant] is a keyword table over the registry snapshot and the service
/// and expense records already on the screen, which is why it can be free and
/// also why it cannot invent anything.
///
/// The suggestions are not decoration. A blank box with a cursor asks the
/// reader to guess what a machine understands; three real questions teach the
/// shape of the thing in less time than a sentence of instructions would.
///
/// When nothing matches, it says so and does not guess. That is the whole
/// difference between this being useful and being noise.
class CarAssistantCard extends ConsumerStatefulWidget {
  const CarAssistantCard({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<CarAssistantCard> createState() => _CarAssistantCardState();
}

class _CarAssistantCardState extends ConsumerState<CarAssistantCard> {
  final _controller = TextEditingController();
  AssistantAnswer? _answer;
  bool _asked = false;

  static const _suggestions = [
    'מתי הטסט הבא?',
    'כמה הוצאתי השנה?',
    'מתי החלפתי צמיגים?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Answers from state the caller has already **watched**, never from a
  /// `ref.read` taken here.
  ///
  /// Both lists arrive as `AsyncValue` rather than as lists, so that "still
  /// loading" survives the trip. Flattening them with `?? const []` was how
  /// this card came to tell owners they had recorded no expenses this year:
  /// the overview tab never subscribed to the expense stream, so the first
  /// question anybody asked was answered from an empty list that only meant
  /// "not here yet". `_ask` runs once per question and never re-runs, so that
  /// answer stayed on screen.
  void _ask(
    String question, {
    required AsyncValue<List<ServiceRecord>> services,
    required AsyncValue<List<Expense>> expenses,
  }) {
    final snapshot = widget.vehicle.govSnapshot;
    final vehicle = widget.vehicle;
    final gov = snapshot == null ? null : GovData.fromSnapshot(snapshot);

    // Two places record what we know about recalls, and they are not
    // interchangeable. `lastRecallCheckAt` is the daily check the app runs and
    // is what the red banner above this card is drawn from, so when it has run
    // it wins — otherwise the card and the banner could disagree about the
    // same car on the same screen. Failing that, the snapshot taken when the
    // vehicle was added still knows whether the recall endpoint answered, and
    // an endpoint that answered and listed nothing is a real answer.
    //
    // Neither source present means no check ever ran, which is not the same
    // fact as a register that came back clean.
    final checkedLive = vehicle.lastRecallCheckAt != null;
    final snapshotAnswered = gov?.answered(GovDataset.recalls) ?? false;

    setState(() {
      _asked = true;
      _answer = CarAssistant.answer(
        question,
        AssistantContext(
          // The snapshot was copied when the vehicle was added, so this answers
          // from the same record the rest of the screen shows. If it is absent
          // the assistant says it has nothing rather than pretending.
          gov: gov,
          openRecalls:
              checkedLive ? vehicle.openRecallCount : (gov?.recalls.length ?? 0),
          recallsChecked: checkedLive || snapshotAnswered,
          recordsLoaded: services.hasValue && expenses.hasValue,
          services: services.valueOrNull ?? const [],
          expenses: expenses.valueOrNull ?? const [],
          now: DateTime.now(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Watched, not read. The overview tab does not subscribe to the expense
    // stream on its own, so reading it cold inside the callback returned
    // `AsyncLoading` and the answer was built from nothing.
    final services = ref.watch(vehicleServicesProvider(widget.vehicle.id));
    final expenses = ref.watch(vehicleExpensesProvider(widget.vehicle.id));
    void ask(String question) =>
        _ask(question, services: services, expenses: expenses);

    return AppSectionCard(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'שאלו על הרכב',
      subtitle:
          'התשובות מגיעות מהנתונים שכבר יש כאן. שום שאלה לא נשלחת לשום מקום.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: ask,
            decoration: InputDecoration(
              hintText: 'למשל: מתי הטסט הבא?',
              isDense: true,
              suffixIcon: IconButton(
                // Not `Icons.arrow_back`: it is `matchTextDirection`, so in
                // RTL it mirrors into a right-pointing arrow — the glyph this
                // app uses for "back" on every other screen. `Icons.send` is
                // what the chat composer already uses to mean send.
                icon: const Icon(Icons.send, size: 20),
                tooltip: 'שאל',
                onPressed: () => ask(_controller.text),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),

          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final s in _suggestions)
                ActionChip(
                  label: Text(s, style: context.text.caption),
                  onPressed: () {
                    _controller.text = s;
                    ask(s);
                  },
                ),
            ],
          ),

          if (_asked) ...[
            const SizedBox(height: AppSpace.md),
            if (_answer == null)
              // Said plainly. An assistant that answers everything is an
              // assistant that answers some things wrongly.
              Text(
                'לא הבנתי את השאלה. אפשר לנסות אחת מההצעות למעלה.',
                style: AppText.body.copyWith(color: colors.textMuted),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.md),
                // Neutral, deliberately. `tealLight` is not a neutral in this
                // app — three screens pair it against `warnBg` as an explicit
                // good/bad ternary — so "תוקף הרישיון פג לפני 42 ימים" was
                // being delivered in the reassurance colour.
                //
                // And the fix is not to switch the fill on sentiment: colour
                // is a claim too, and an assistant that tints its answers is
                // appraising the car, which the class above forbids in words.
                // The box holds an answer and says nothing about it.
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border.all(color: colors.cardBorder),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_answer!.text,
                        style: AppText.body.copyWith(color: colors.textPrimary)),
                    const SizedBox(height: AppSpace.xs),
                    // Every answer carries its origin. The app shows its work
                    // rather than asking to be believed.
                    Text(_answer!.source, style: context.text.micro),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
