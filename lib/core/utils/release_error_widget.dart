import 'package:flutter/material.dart';

/// What is drawn where a widget failed to build.
///
/// **Flutter's release default is a grey rectangle with no text**, and that
/// default cost a day. The fuel screen came back from a real phone as "empty
/// screen" — no skeleton, so not loading; no message, so not the error branch.
/// An app that knows exactly which exception was thrown and paints a blank box
/// over it cannot be diagnosed from the outside, and the person reporting it
/// has nothing to report but "it doesn't work".
///
/// So this replaces it: the same failure, said out loud. A short Hebrew line
/// for the reader, and underneath it the exception itself — because the
/// fastest bug report in the world is a screenshot of the actual error.
///
/// It stays in release builds on purpose. The alternative is not "a tidier
/// app", it is the grey box, and the grey box is worse for everyone.
class ReleaseErrorWidget extends StatelessWidget {
  const ReleaseErrorWidget(this.details, {super.key});

  final FlutterErrorDetails details;

  /// Installs this as the app-wide builder. Call before `runApp`.
  static void install() {
    ErrorWidget.builder = (details) => ReleaseErrorWidget(details);
  }

  @override
  Widget build(BuildContext context) {
    // Deliberately not `context.colors`: a theme lookup is itself a thing that
    // can fail, and an error widget that throws while reporting an error takes
    // the whole app down instead of one subtree.
    const ink = Color(0xFF1A1A1A);
    const muted = Color(0xFF6B6B6B);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: const Color(0xFFFFF4F4),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.error_outline, size: 40, color: muted),
                const SizedBox(height: 12),
                const Text(
                  'משהו במסך הזה נשבר',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: ink),
                ),
                const SizedBox(height: 6),
                const Text(
                  'שאר האפליקציה עובדת. אם תשלחו צילום של המסך הזה, '
                  'הפרטים למטה הם בדיוק מה שדרוש כדי לתקן.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE4D4D4)),
                      ),
                      // LTR: an exception and a stack trace are not Hebrew,
                      // and RTL turns them into something nobody can read.
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          _summary,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color: ink,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The exception plus the first few frames of app code.
  ///
  /// Trimmed to what fits on a phone screen and identifies the fault: the
  /// framework's own frames are the same for every bug and push the useful
  /// line off the bottom.
  String get _summary {
    final buffer = StringBuffer(details.exceptionAsString());
    final stack = details.stack;
    if (stack != null) {
      final frames = stack
          .toString()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .take(12)
          .toList();
      if (frames.isNotEmpty) {
        buffer.write('\n\n');
        buffer.write(frames.join('\n'));
      }
    }
    return buffer.toString();
  }
}
