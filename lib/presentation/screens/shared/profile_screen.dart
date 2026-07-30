import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/guest_prompt_view.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(authStateProvider).valueOrNull == null;
    final userAsync = ref.watch(currentUserModelProvider);

    if (isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('פרופיל')),
        body: const SafeArea(
          child: GuestPromptView(
            icon: Icons.person_outline,
            title: 'הפרופיל שלך',
            body: 'התחבר כדי לנהל מודעות, שמורים והתכתבויות.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('פרופיל')),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('שגיאה בטעינת הפרופיל',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          data: (user) => _Content(user: user, ref: ref),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.user, required this.ref});
  final UserModel? user;
  final WidgetRef ref;

  Future<void> _signOut(BuildContext context) async {
    await ref.read(authRepositoryProvider).signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final name = (user?.name.isNotEmpty ?? false)
        ? user!.name
        : 'משתמש OtoV';
    final verified = user?.verified ?? false;

    return ListView(
      children: [
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              const CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.tealLight,
                child: Icon(Icons.person, size: 48, color: AppColors.teal),
              ),
              const SizedBox(height: 12),
              Text(name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              if (verified)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 16, color: AppColors.teal),
                    SizedBox(width: 4),
                    Text('מוכר מאומת',
                        style: TextStyle(color: AppColors.teal)),
                  ],
                )
              else
                Text(user?.phone ?? '',
                    style: const TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _MenuRow(
          icon: Icons.directions_car_outlined,
          label: 'המודעות שלי',
          onTap: () => context.go('/seller'),
        ),
        _MenuRow(
          icon: Icons.favorite_border,
          label: 'רכבים שמורים',
          onTap: () => context.go('/saved'),
        ),
        _MenuRow(
          icon: Icons.verified_user_outlined,
          label: verified ? 'סטטוס אימות: מאומת ✓' : 'אימות מוכר',
          onTap: () => context.push('/verify/role'),
        ),
        _MenuRow(
          icon: Icons.info_outline,
          label: 'אודות OtoV',
          onTap: () => context.push('/about'),
        ),
        const Divider(height: 32),
        _MenuRow(
          icon: Icons.logout,
          label: 'התנתקות',
          color: AppColors.errorRed,
          onTap: () => _signOut(context),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c),
      title: Text(label, style: TextStyle(color: c)),
      trailing: const Icon(Icons.chevron_left, color: AppColors.textSubtle),
      onTap: onTap,
    );
  }
}
