import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assistant/car_assistant.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/gov_data_model.dart';
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

  void _ask(String question) {
    final services =
        ref.read(vehicleServicesProvider(widget.vehicle.id)).valueOrNull ??
            const [];
    final expenses =
        ref.read(vehicleExpensesProvider(widget.vehicle.id)).valueOrNull ??
            const [];
    final snapshot = widget.vehicle.govSnapshot;

    setState(() {
      _asked = true;
      _answer = CarAssistant.answer(
        question,
        AssistantContext(
          // The snapshot was copied when the vehicle was added, so this answers
          // from the same record the rest of the screen shows. If it is absent
          // the assistant says it has nothing rather than pretending.
          gov: snapshot == null ? null : GovData.fromSnapshot(snapshot),
          govReachable: snapshot != null,
          services: services,
          expenses: expenses,
          now: DateTime.now(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 18, color: colors.tealText2),
              const SizedBox(width: AppSpace.sm),
              const Text('שאלו על הרכב', style: AppText.subtitle),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'התשובות מגיעות מהנתונים שכבר יש כאן. שום שאלה לא נשלחת לשום מקום.',
            style: context.text.micro,
          ),
          const SizedBox(height: AppSpace.md),

          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: _ask,
            decoration: InputDecoration(
              hintText: 'למשל: מתי הטסט הבא?',
              isDense: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                tooltip: 'שאל',
                onPressed: () => _ask(_controller.text),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
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
                    _ask(s);
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
                decoration: BoxDecoration(
                  color: colors.tealLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_answer!.text,
                        style: AppText.body.copyWith(color: colors.tealText)),
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
