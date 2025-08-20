import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers_settings.dart';
import 'pages/activities_list_page.dart';

void main() {
  runApp(const ProviderScope(child: HabitsApp()));
}

class HabitsApp extends ConsumerWidget {
  const HabitsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    // Locale depuis les réglages
    Locale? appLocale;
    switch (settings.localeMode) {
      case AppLocaleMode.system:
        appLocale = null;
        break;
      case AppLocaleMode.fr:
        appLocale = const Locale('fr');
        break;
      case AppLocaleMode.en:
        appLocale = const Locale('en');
        break;
    }

    // ThemeMode depuis les réglages
    ThemeMode themeMode;
    switch (settings.themeMode) {
      case AppThemeMode.system:
        themeMode = ThemeMode.system;
        break;
      case AppThemeMode.light:
        themeMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
        themeMode = ThemeMode.dark;
        break;
    }

    return MaterialApp(
      title: 'Habits Timer',
      debugShowCheckedModeBanner: false,

      // Thèmes
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),

      // Localisation
      locale: appLocale,
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const ActivitiesListPage(),
    );
  }
}
