import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_config.dart';
import '../../core/constants/legal_info.dart';

/// Opens the reader's mail app with a support message already addressed and
/// half written.
///
/// The same mailbox the legal documents name for data-deletion and
/// content-removal requests, so there is exactly one address to monitor and
/// exactly one to keep true. It is filled in from [LegalInfo.contactEmail];
/// nothing here hardcodes it.
class SupportContact {
  SupportContact._();

  static bool get isAvailable => LegalInfo.contactEmail.trim().isNotEmpty;

  /// A short technical footer, so a report does not begin with three rounds of
  /// "which version are you on?".
  ///
  /// Deliberately thin: the version and the platform, nothing that identifies
  /// the person. An app that quietly attaches a device fingerprint to a
  /// support email is doing the thing this app exists to argue against.
  static String diagnostics() {
    final platform = kIsWeb
        ? 'דפדפן'
        : defaultTargetPlatform == TargetPlatform.android
            ? 'אנדרואיד'
            : defaultTargetPlatform == TargetPlatform.iOS
                ? 'iOS'
                : 'אחר';
    return 'גרסה ${AppConfig.appVersion} · $platform';
  }

  /// Builds the mailto link. Everything is percent-encoded, which matters here
  /// because both the subject and the body are Hebrew.
  static Uri uriFor({required String subject, String body = ''}) {
    final full = body.isEmpty
        ? '\n\n---\n${diagnostics()}'
        : '$body\n\n---\n${diagnostics()}';
    return Uri(
      scheme: 'mailto',
      path: LegalInfo.contactEmail.trim(),
      query: Uri(queryParameters: {
        'subject': subject,
        'body': full,
      }).query,
    );
  }

  /// Returns false when no mail app could be opened, so the caller can offer
  /// the address as plain text instead of leaving a dead button. A desktop
  /// browser with no mail client configured is the common case.
  static Future<bool> open({
    required String subject,
    String body = '',
  }) async {
    if (!isAvailable) return false;
    try {
      return await launchUrl(
        uriFor(subject: subject, body: body),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}

/// The action behind the profile's "צור קשר" row.
///
/// Kept out of the profile screen so the fallback below — the one that matters
/// on a desktop browser with no mail client — lives next to the code that
/// builds the link, rather than three files away from it.
class SupportRow {
  SupportRow._();

  static Future<void> contact(BuildContext context) async {
    final ok = await SupportContact.open(subject: 'פנייה לתמיכה — BonnetCheck');
    if (ok || !context.mounted) return;

    // No mail app. Show the address so the person can still write to us from
    // wherever they read their mail.
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('כתובת התמיכה'),
        content: SelectableText(
          '${LegalInfo.contactEmail}\n\n${SupportContact.diagnostics()}',
          textDirection: TextDirection.ltr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('סגור'),
          ),
        ],
      ),
    );
  }
}
