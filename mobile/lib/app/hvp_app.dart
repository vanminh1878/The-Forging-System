import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/hvp_theme.dart';
import '../core/design/theme_mode_controller.dart';
import 'router.dart';

/// Lets mouse and trackpad drag scrollables (useful when debugging in Chrome).
class HvpScrollBehavior extends MaterialScrollBehavior {
  const HvpScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Root widget: theme (dark by default), Vietnamese locale, router.
class HvpApp extends ConsumerWidget {
  const HvpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'HVP Forging System',
      debugShowCheckedModeBanner: false,
      theme: HvpTheme.light(),
      darkTheme: HvpTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      scrollBehavior: const HvpScrollBehavior(),
      locale: const Locale('vi', 'VN'),
      supportedLocales: const <Locale>[Locale('vi', 'VN')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
