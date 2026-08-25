import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/account_deletion_repository.dart';
import '../../../core/theme/app_palette.dart';
import '../../providers/theme_provider.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/constants/app_config.dart';
import '../../widgets/analytics_consent_gate.dart';
import '../../widgets/app_card.dart';
import '../../widgets/guest_prompt_view.dart';
import '../../../core/theme/app_text.dart';
import '../../widgets/saved_check_icon.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/support_contact.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(authStateProvider).valueOrNull == null;
    final userAsync = ref.watch(currentUserModelProvider);

    if (isGuest) {
      // A guest gets the sign-in prompt AND the two things that must never sit
      // behind an account: the measurement switch and the legal documents.
      //
      // The guest is precisely the person who was asked about analytics on
      // first launch — and until this was here, somebody who tapped
      // "אפשר למדוד" had no way back. GDPR Art. 7(3) requires withdrawal to
      // be as easy as consent was to give, and both stores expect a route to
      // the privacy policy from inside the app. Neither can depend on having
      // signed up.
      return Scaffold(
        appBar: AppBar(title: const Text('פרופיל')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.xxl),
            children: [
              const SizedBox(height: AppSpace.xl),
              const GuestPromptView(
                icon: Icons.person_outline,
                title: 'הפרופיל שלך',
                body: 'התחבר כדי לנהל מודעות, שמורים והתכתבויות.',
                fillHeight: false,
              ),
              const SizedBox(height: AppSpace.xl),
              _MenuGroup(rows: [
                const AnalyticsConsentTile(),
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
              const _VersionLine(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('פרופיל')),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorRetry(
            message: 'לא הצלחנו לטעון את הפרופיל',
            onRetry: () => ref.invalidate(currentUserModelProvider),
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

  /// Deletes the account, in the app, now.
  ///
  /// It used to file a *request* into a collection no client can read, which
  /// Apple rejects outright (§5.1.1(v)) and which the product could not
  /// actually keep. The entanglement worry behind that decision was real but
  /// misapplied: what belongs to this person — their listings, their
  /// passports, their saved cars — goes with them. What they wrote **about
  /// other people's cars** (visitor notes, seller-encounter reports) is other
  /// buyers' evidence, so it stays and is not tied back to a live account.
  ///
  /// The dialog lists all of that before anything happens, because a
  /// destructive action that surprises somebody is worse than no button.
  Future<void> _requestDeletion(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('מחיקת החשבון'),
        content: const Text(
            'הפעולה הזו מוחקת עכשיו, ואי אפשר לבטל אותה:\n\n'
            '• המודעה שפרסמתם, אם יש\n'
            '• תיקי הרכב שלכם וכל מה שתיעדתם בהם\n'
            '• הרכבים ששמרתם והחשבון עצמו\n\n'
            'הערות ודיווחים שכתבתם על רכבים של אחרים יישארו — קונים אחרים '
            'נשענים עליהם — והם אינם מקושרים לחשבון חי.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('מחקו את החשבון')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(accountDeletionRepositoryProvider).deleteEverything();
      if (context.mounted) context.go('/login');
    } on AccountDeletionNeedsRecentLogin {
      // Firebase refuses to delete a credential on an old sign-in. The data
      // is already gone by this point, so say exactly that rather than
      // implying nothing happened.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('המידע נמחק. כדי למחוק את החשבון עצמו, התחברו שוב '
                'ולחצו שוב על מחיקה.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('המחיקה נכשלה. נסו שוב.')),
        );
      }
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
          const AnalyticsConsentTile(),
          // The comparison against the registry is no longer a thing you do
          // on its own — it is the first step of publishing, where it has a
          // purpose. This row leads there rather than to a verification flow
          // that ended in a screen congratulating you for finishing it.
          if (!verified)
            _MenuRow(
              icon: Icons.verified_user_outlined,
              label: 'פרסום מודעה והשוואה למרשם',
              onTap: () => context.push('/seller/create'),
            ),
          _MenuRow(
            icon: Icons.info_outline,
            label: 'אודות BonnetCheck',
            onTap: () => context.push('/about'),
          ),
          // Hidden until a support address exists — the same gate the legal
          // documents use. An app must never offer a way to reach somebody
          // who cannot be reached.
          if (SupportContact.isAvailable)
            _MenuRow(
              icon: Icons.support_agent_outlined,
              label: 'צור קשר',
              onTap: () => SupportRow.contact(context),
            ),
          _MenuRow(
            icon: Icons.gavel_outlined,
            label: 'תנאי שימוש ופרטיות',
            onTap: () => context.push('/legal'),
          ),
        ]),
        const SizedBox(height: AppSpace.md),
        const _ThemeToggle(),
        const _VersionLine(),
        const SizedBox(height: AppSpace.md),
        // The two actions you cannot simply undo, kept apart from navigation
        // and marked. The reference design put the terms-of-use link in this
        // group and coloured it red too — that would flag a page of text as
        // dangerous, so it stays above with the rest of the navigation.
        _MenuGroup(rows: [
          _MenuRow(
            icon: Icons.delete_sweep_outlined,
            label: 'מחיקת החשבון והמידע שלי',
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

/// The build the person is actually holding.
///
/// It existed only inside the support email's footer until 25/08, and that is
/// half a version number: the first thing anyone needs when a friend says "it
/// doesn't work" is which build they have, and neither of them could see it.
/// Side-loaded copies make this worse than it would be in a store, where the
/// installed version is one tap away in Settings.
///
/// Quiet on purpose — nobody opens the profile to read this, they come looking
/// for it once.
class _VersionLine extends StatelessWidget {
  const _VersionLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg),
      child: Center(
        child: Text(
          'BonnetCheck ${AppConfig.appVersion}',
          style: context.text.micro,
        ),
      ),
    );
  }
}
