import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../providers/theme_provider.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../../core/theme/app_dimens.dart';
import '../../widgets/app_card.dart';
import '../../widgets/guest_prompt_view.dart';
import '../../../core/theme/app_text.dart';
import '../../widgets/saved_check_icon.dart';

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
        : 'משתמש BonnetCheck';
    final verified = user?.verified ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.xl),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: context.colors.tealLight,
                child: Icon(Icons.person, size: 34, color: context.colors.teal),
              ),
              const SizedBox(height: AppSpace.md),
              Text(name, style: AppText.title),
              const SizedBox(height: AppSpace.sm),
              // Completed comparison is a STATE, so it reads as a badge. When
              // it hasn't been done it is a task instead, and appears as a row
              // in the menu below — a thing to do does not belong in a badge.
              if (verified)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md, vertical: 5),
                  decoration: BoxDecoration(
                    color: context.colors.tealLight,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 13, color: context.colors.tealText),
                      const SizedBox(width: AppSpace.xs + 1),
                      Text('השוואה למרשם: הושלמה',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: context.colors.tealText,
                          )),
                    ],
                  ),
                )
              else if ((user?.phone ?? '').isNotEmpty)
                Text(user!.phone, style: context.text.caption),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        _MenuGroup(rows: [
          // Not a car glyph any more: the garage tab took that meaning, and
          // two rows apart showing the same icon for "my listings" and "my
          // vehicle" would read as the same destination.
          _MenuRow(
            icon: Icons.sell_outlined,
            label: 'המודעות שלי',
            onTap: () => context.go('/seller'),
          ),
          _MenuRow(
            icon: Icons.check_rounded,
            iconWidget:
                SavedCheckIcon(size: 18, color: context.colors.textMuted),
            label: 'רכבים שמורים',
            onTap: () => context.push('/saved'),
          ),
          _MenuRow(
            icon: Icons.history,
            label: 'רכבים שהיו בבעלותי',
            onTap: () => context.push('/profile/past-vehicles'),
          ),
          if (!verified)
            _MenuRow(
              icon: Icons.verified_user_outlined,
              label: 'השוואה למרשם הרכב',
              onTap: () => context.push('/verify/role'),
            ),
          _MenuRow(
            icon: Icons.info_outline,
            label: 'אודות BonnetCheck',
            onTap: () => context.push('/about'),
          ),
          _MenuRow(
            icon: Icons.gavel_outlined,
            label: 'תנאי שימוש ופרטיות',
            onTap: () => context.push('/legal'),
          ),
        ]),
        const SizedBox(height: AppSpace.md),
        const _ThemeToggle(),
        const SizedBox(height: AppSpace.md),
        // The two actions you cannot simply undo, kept apart from navigation
        // and marked. The reference design put the terms-of-use link in this
        // group and coloured it red too — that would flag a page of text as
        // dangerous, so it stays above with the rest of the navigation.
        _MenuGroup(rows: [
          _MenuRow(
            icon: Icons.delete_sweep_outlined,
            label: 'בקשת מחיקת המידע שלי',
            color: context.colors.errorRed,
            showChevron: false,
            onTap: () => _requestDeletion(context, ref),
          ),
          _MenuRow(
            icon: Icons.logout,
            label: 'התנתקות',
            color: context.colors.errorRed,
            showChevron: false,
            onTap: () => _signOut(context),
          ),
        ]),
      ],
    );
  }
}

/// Menu rows as one card with hairlines between them, rather than a run of
/// full-bleed list tiles. The grouping is the information: navigation in one
/// block, the settings in another, the things you cannot undo in a third.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: context.colors.cardBorder),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// Dark mode as a plain on/off switch, like the location toggle in a phone's
/// settings.
///
/// The underlying setting still has three states — light, dark, and follow
/// the device — and the device is still the default, since someone whose
/// phone is already dark has answered this question once. A switch can only
/// show two, so while the setting is "follow the device" the switch mirrors
/// what the device is currently doing and says so underneath. Touching it is
/// what turns that into a deliberate choice, and a reset link appears to hand
/// the decision back.
class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final deviceIsDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    final isDark = switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => deviceIsDark,
    };

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.sm, AppSpace.md, AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: 18,
                color: context.colors.textMuted,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('מצב כהה', style: AppText.bodySm),
                    const SizedBox(height: 1),
                    Text(
                      mode == ThemeMode.system
                          ? 'לפי הגדרות המכשיר'
                          : (isDark ? 'דולק' : 'כבוי'),
                      style: context.text.micro,
                    ),
                  ],
                ),
              ),
              Switch(
                value: isDark,
                onChanged: (on) => ref
                    .read(themeModeProvider.notifier)
                    .set(on ? ThemeMode.dark : ThemeMode.light),
              ),
            ],
          ),
          if (mode != ThemeMode.system)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.tealText2,
                  textStyle: const TextStyle(fontSize: 12.5),
                ),
                icon: const Icon(Icons.brightness_auto_outlined, size: 16),
                label: const Text('חזרה להגדרות המכשיר'),
                onPressed: () =>
                    ref.read(themeModeProvider.notifier).set(ThemeMode.system),
              ),
            ),
        ],
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
    this.iconWidget,
    this.showChevron = true,
  });

  final IconData icon;

  /// Drawn instead of [icon] when the mark isn't a Material glyph.
  final Widget? iconWidget;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  /// A chevron means "this opens a page". Rows that fire an action instead —
  /// signing out, filing a deletion request — do not get one, because it would
  /// promise a screen they can back out of.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final label_ = color ?? context.colors.textPrimary;
    final iconColor = color ?? context.colors.textMuted;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.md + 2),
        child: Row(
          children: [
            iconWidget ?? Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(color: label_)),
            ),
            if (showChevron)
              Icon(Icons.chevron_left,
                  size: 18, color: context.colors.textSubtle),
          ],
        ),
      ),
    );
  }
}
