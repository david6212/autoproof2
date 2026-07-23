import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';

/// Shows a friendly bottom sheet inviting a guest to sign in before doing an
/// action that requires an account (save, chat, like...).
///
/// [action] completes the sentence "כדי ל<action> צריך חשבון" — e.g. "לשמור
/// רכבים", "לשלוח הודעה". Returns nothing; navigation to /login is handled here.
Future<void> showLoginRequired(
  BuildContext context, {
  required String action,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock icon in a soft teal circle.
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.tealLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline,
                    color: AppColors.teal, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'כדי $action צריך חשבון',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'ההתחברות מהירה — רק מספר טלפון וקוד SMS.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/login');
                  },
                  child: const Text('התחברות',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('אולי אחר כך',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      );
    },
  );
}
