import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/car_model.dart';
import '../../providers/seller_verification_provider.dart';
import '../../../core/theme/app_dimens.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button_widget.dart';
import '../../widgets/step_progress_widget.dart';
import '../../../core/theme/app_text.dart';

class VerifyRoleScreen extends ConsumerStatefulWidget {
  const VerifyRoleScreen({super.key});

  @override
  ConsumerState<VerifyRoleScreen> createState() => _VerifyRoleScreenState();
}

class _VerifyRoleScreenState extends ConsumerState<VerifyRoleScreen> {
  SellerType? _selected;

  void _continue() {
    ref
        .read(sellerVerificationControllerProvider.notifier)
        .setSellerType(_selected!);
    context.go('/verify/plate');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('אימות מוכר')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepProgress(current: 1),
              const SizedBox(height: AppSpace.xl),
              // h3, like every other step title in the app. The step bar above
              // already says where you are.
              const Text('מי אתה?', style: AppText.h3),
              const SizedBox(height: AppSpace.xs + 2),
              Text(
                'הסיווג שתבחר יוצג בבירור במודעה, כדי שהקונה יידע כיצד סיווגת את עצמך.',
                style: context.text.bodySmMuted,
              ),
              const SizedBox(height: AppSpace.xl),

              _RoleOption(
                selected: _selected == SellerType.private,
                icon: Icons.person_outline,
                title: AppStrings.verifyOwnerYes,
                subtitle: 'אמת את זהותך מול מרשם הרכב',
                onTap: () => setState(() => _selected = SellerType.private),
              ),
              const SizedBox(height: AppSpace.md),
              _RoleOption(
                selected: _selected == SellerType.agent,
                icon: Icons.handshake_outlined,
                title: 'אני סוכן',
                subtitle: 'מוכר רכב בשם מישהו אחר',
                onTap: () => setState(() => _selected = SellerType.agent),
              ),
              const SizedBox(height: AppSpace.md),
              _RoleOption(
                selected: _selected == SellerType.dealer,
                icon: Icons.store_outlined,
                title: 'אני סוחר / מגרש',
                subtitle: 'עסק למכירת רכבים',
                onTap: () => setState(() => _selected = SellerType.dealer),
              ),

              const Spacer(),
              PrimaryButton(
                label: AppStrings.continueBtn,
                onPressed: _selected != null ? _continue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // AppCard, not a hand-rolled Container. It already carries the surface,
    // the radius and — since the comparison screen — a border colour and
    // width, which is exactly what a selected option needs.
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpace.lg),
      color: selected ? context.colors.tealLight : null,
      borderColor: selected ? context.colors.teal : null,
      borderWidth: selected ? 2 : 1,
      child: Row(
        children: [
          Icon(icon, color: context.colors.teal, size: 26),
          const SizedBox(width: AppSpace.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.subtitle),
                const SizedBox(height: AppSpace.xs),
                Text(subtitle, style: context.text.caption),
              ],
            ),
          ),
          // The selection is already carried by the fill and the 2px border;
          // the tick is the third signal, so it does not rely on colour alone.
          if (selected)
            Icon(Icons.check_circle, size: 22, color: context.colors.tealText),
        ],
      ),
    );
  }
}
