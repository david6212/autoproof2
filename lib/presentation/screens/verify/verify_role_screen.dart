import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../widgets/primary_button_widget.dart';
import '../../widgets/step_progress_widget.dart';

class VerifyRoleScreen extends StatefulWidget {
  const VerifyRoleScreen({super.key});

  @override
  State<VerifyRoleScreen> createState() => _VerifyRoleScreenState();
}

class _VerifyRoleScreenState extends State<VerifyRoleScreen> {
  bool _privateSelected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('אימות מוכר')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepProgress(current: 1),
              const SizedBox(height: 28),
              const Text(
                'מי אתה?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'AutoProof פתוחה לבעלים פרטיים בלבד.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),

              _RoleOption(
                selected: _privateSelected,
                enabled: true,
                icon: Icons.person_outline,
                title: AppStrings.verifyOwnerYes,
                subtitle: 'אמת את זהותך מול מרשם הרכב',
                onTap: () => setState(() => _privateSelected = true),
              ),
              const SizedBox(height: 14),
              const _RoleOption(
                selected: false,
                enabled: false,
                icon: Icons.store_outlined,
                title: AppStrings.verifyDealer,
                subtitle: 'סוחרים וסוכנויות אינם רשאים לפרסם ב-AutoProof',
                onTap: null,
              ),

              const Spacer(),
              PrimaryButton(
                label: AppStrings.continueBtn,
                onPressed:
                    _privateSelected ? () => context.go('/verify/plate') : null,
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
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.teal : AppColors.cardBorder;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppColors.tealLight : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.teal, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.teal),
            ],
          ),
        ),
      ),
    );
  }
}
