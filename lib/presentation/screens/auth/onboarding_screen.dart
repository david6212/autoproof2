import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/constants/app_strings.dart';
import '../../widgets/onboarding_art.dart';
import '../../widgets/primary_button_widget.dart';
import '../../../core/theme/app_text.dart';

class _Slide {
  const _Slide(this.title, this.body);
  final String title;
  final String body;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  // The picture for each is [OnboardingArt], drawn from the slide's index.
  static const _slides = [
    _Slide(AppStrings.onboard1Title, AppStrings.onboard1Body),
    _Slide(AppStrings.onboard2Title, AppStrings.onboard2Body),
    _Slide(AppStrings.onboard3Title, AppStrings.onboard3Body),
  ];

  bool get _isLast => _page == _slides.length - 1;

  void _next() {
    if (_isLast) {
      context.go('/login');
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.go('/login'),
                child: Text(
                  AppStrings.skip,
                  style: TextStyle(color: context.colors.textMuted),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Was a single Material glyph in a rounded square —
                        // the same shape three times, telling the reader
                        // nothing the heading had not already said.
                        OnboardingArt(index: i),
                        const SizedBox(height: 28),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: AppText.display,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? context.colors.teal : context.colors.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            // Sets expectations before the user ever sees a listing: what the
            // app is a source of, and what it is not evidence of.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                AppStrings.entryDisclaimer,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5, height: 1.4, color: context.colors.textSubtle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: PrimaryButton(
                label: AppStrings.continueBtn,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
