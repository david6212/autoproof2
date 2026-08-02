import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_dimens.dart';
import '../../providers/theme_provider.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../widgets/guest_prompt_view.dart';
import '../../../core/theme/app_text.dart';

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
          error: (_, __) => Center(
            child: Text('שגיאה בטעינת הפרופיל',
                style: TextStyle(color: context.colors.textMuted)),
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

  /// Files a deletion request. Deliberately a request rather than an instant
  /// wipe: listings and reports a user left are entangled with other people's
  /// records, so each case is handled rather than cascaded blindly.
  Future<void> _requestDeletion(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('בקשת מחיקת מידע'),
        content: const Text(
            'נטפל בבקשה ונמחק את המידע האישי שלך מהמערכת. מודעות ודיווחים שפרסמת '
            'ייבדקו בנפרד. נחזור אליך באמצעי הקשר הרשום בחשבון.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('שלח בקשה')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(submitCorrectionProvider).call(kind: 'account_deletion');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הבקשה נשלחה. נטפל בה ונעדכן אותך.')),
      );
    }
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
              CircleAvatar(
                radius: 44,
                backgroundColor: context.colors.tealLight,
                child: Icon(Icons.person, size: 48, color: context.colors.teal),
              ),
              const SizedBox(height: 12),
              Text(name,
                  style: AppText.h2),
              const SizedBox(height: 4),
              if (verified)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 16, color: context.colors.teal),
                    const SizedBox(width: 4),
                    Text('נתונים ממרשם הרכב',
                        style: TextStyle(color: context.colors.teal)),
                  ],
                )
              else
                Text(user?.phone ?? '',
                    style: TextStyle(color: context.colors.textMuted)),
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
          label: verified ? 'השוואה למרשם: הושלמה ✓' : 'השוואה למרשם הרכב',
          onTap: () => context.push('/verify/role'),
        ),
        _MenuRow(
          icon: Icons.info_outline,
          label: 'אודות OtoV',
          onTap: () => context.push('/about'),
        ),
        _MenuRow(
          icon: Icons.gavel_outlined,
          label: 'תנאי שימוש ופרטיות',
          onTap: () => context.push('/legal'),
        ),
        const Divider(height: 24),
        const _ThemePicker(),
        const Divider(height: 24),
        // A visible, self-serve route to have personal data removed.
        _MenuRow(
          icon: Icons.delete_sweep_outlined,
          label: 'בקשת מחיקת המידע שלי',
          onTap: () => _requestDeletion(context, ref),
        ),
        _MenuRow(
          icon: Icons.logout,
          label: 'התנתקות',
          color: context.colors.errorRed,
          onTap: () => _signOut(context),
        ),
      ],
    );
  }
}

/// Light / dark / follow-the-device.
///
/// "לפי המכשיר" is first and is the default: someone who has already set
/// their phone to dark has answered this question once already.
class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  static const _options = [
    (ThemeMode.system, Icons.brightness_auto_outlined, 'לפי המכשיר'),
    (ThemeMode.light, Icons.light_mode_outlined, 'בהיר'),
    (ThemeMode.dark, Icons.dark_mode_outlined, 'כהה'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('מראה', style: context.text.caption),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (value, icon, label) in _options)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _ThemeOption(
                      icon: icon,
                      label: label,
                      selected: mode == value,
                      onTap: () =>
                          ref.read(themeModeProvider.notifier).set(value),
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

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? context.colors.onBrand : context.colors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? context.colors.teal : context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? context.colors.teal : context.colors.cardBorder,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
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
    final c = color ?? context.colors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c),
      title: Text(label, style: TextStyle(color: c)),
      trailing: Icon(Icons.chevron_left, color: context.colors.textSubtle),
      onTap: onTap,
    );
  }
}
