import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_strings.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/widgets/responsive_frame.dart';
import 'router.dart';
import 'theme.dart';

class BonnetCheckApp extends ConsumerWidget {
  const BonnetCheckApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      // Force RTL layout throughout the app, and centre it on a window too
      // wide to be a phone. Both wrap the Navigator, so they apply to every
      // screen, dialog and bottom sheet without touching them individually.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        // The OS status-bar icons, for every screen — including the ones with
        // NO app bar (splash, onboarding, login, home). `AppBarTheme` only
        // reaches screens that have a bar, so those four were inheriting
        // whatever the last screen happened to set. Now that every surface at
        // the top of the app is light, the icons have to be dark everywhere.
        value: Theme.of(context).brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: ResponsiveFrame(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
