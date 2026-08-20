import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/constants/legal_docs.dart';
import '../../../core/constants/legal_info.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../widgets/app_card.dart';

/// Index of the legal documents.
///
/// Shows the documents only once [LegalInfo] names a real operator and a real
/// mailbox — see the comment there for why.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('מידע משפטי')),
      body: SafeArea(
        child: LegalInfo.isPublished
            ? _Index()
            : const _PendingNotice(),
      ),
    );
  }
}

class _Index extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        Text('עודכן לאחרונה: ${LegalInfo.lastUpdated}',
            style: context.text.caption),
        const SizedBox(height: AppSpace.lg),
        for (final doc in LegalDocs.all)
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpace.md),
            onTap: () => context.push('/legal/${doc.id}'),
            child: Row(
              children: [
                Icon(_iconFor(doc.id), color: context.colors.teal),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc.title, style: AppText.subtitle),
                      const SizedBox(height: AppSpace.xs),
                      Text(doc.summary, style: context.text.caption),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left, color: context.colors.textSubtle),
              ],
            ),
          ),
        const SizedBox(height: AppSpace.sm),
        Text(
          'המסמכים נועדו להסביר בשפה ברורה מה השירות עושה ומה לא. '
          'אין בהם ייעוץ משפטי.',
          style: context.text.caption,
        ),
      ],
    );
  }
}

/// Stand-in shown while the operator's details are still blank. Deliberately
/// says what is missing rather than showing a document with holes in it.
class _PendingNotice extends StatelessWidget {
  const _PendingNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined,
                size: 48, color: context.colors.textSubtle),
            const SizedBox(height: AppSpace.lg),
            const Text('המסמכים המשפטיים בהכנה',
                style: AppText.h3, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.sm),
            Text(
              'תנאי השימוש, מדיניות הפרטיות ושאר המסמכים ייפורסמו כאן עם '
              'השלמת פרטי המפעיל. עד אז, ההבהרות לגבי מה שהשירות בודק ומה לא '
              'מופיעות במסך "אודות".',
              style: context.text.bodySmMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.lg),
            TextButton(
              onPressed: () => context.push('/about'),
              child: const Text('למסך אודות'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single document.
class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.docId});

  final String docId;

  @override
  Widget build(BuildContext context) {
    final doc = LegalDocs.byId(docId);

    if (doc == null || !LegalInfo.isPublished) {
      return Scaffold(
        appBar: AppBar(title: const Text('מידע משפטי')),
        body: const SafeArea(child: _PendingNotice()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            Text(doc.title, style: AppText.h2),
            const SizedBox(height: AppSpace.xs),
            Text('עודכן לאחרונה: ${LegalInfo.lastUpdated}',
                style: context.text.caption),
            const SizedBox(height: AppSpace.xl),
            for (final section in doc.sections) _Section(section: section),
            const SizedBox(height: AppSpace.xl),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.heading, style: AppText.subtitle),
          const SizedBox(height: AppSpace.sm),
          for (final p in section.paragraphs) _Paragraph(text: p),
        ],
      ),
    );
  }
}

/// Renders one paragraph. A leading `• ` becomes a hanging bullet so the
/// wrapped lines stay aligned under the text, not under the dot.
class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isBullet = text.startsWith('• ');
    if (!isBullet) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Text(text, style: AppText.body),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•', style: AppText.body),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(text.substring(2), style: AppText.body),
          ),
        ],
      ),
    );
  }
}

/// The glyph for each document.
///
/// It lives here rather than in `LegalDocs` because the documents are text,
/// and text that carries a Material icon cannot be read by anything but a
/// Flutter screen. `tool/gen_legal.dart` renders the same documents as static
/// HTML for the site, and it can only import them because they are now plain
/// Dart.
IconData _iconFor(String id) {
  switch (id) {
    case LegalDocs.terms:
      return Icons.gavel_outlined;
    case LegalDocs.privacy:
      return Icons.lock_outline;
    case LegalDocs.cookies:
      return Icons.cookie_outlined;
    case LegalDocs.removal:
      return Icons.playlist_remove_outlined;
    case LegalDocs.complaints:
      return Icons.support_agent_outlined;
    default:
      return Icons.description_outlined;
  }
}
