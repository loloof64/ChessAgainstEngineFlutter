import 'package:chess_against_engine/screens/new_game_position_editor.dart';

import '../screens/settings_screen.dart';
import '../screens/new_game_screen.dart';
import '../screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/loaders/decoders/yaml_decode_strategy.dart';

import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logger/logger.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => FlutterI18n.translate(context, 'app.title'),
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      localizationsDelegates: [
        FlutterI18nDelegate(
          translationLoader: FileTranslationLoader(
            basePath: 'assets/i18n',
            useCountryCode: false,
            fallbackFile: 'en',
            decodeStrategies: [YamlDecodeStrategy()],
          ),
          missingTranslationHandler: (key, locale) {
            Logger().w(
                "--- Missing Key: $key, languageCode: ${locale?.languageCode}");
          },
        ),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('fr', ''),
        Locale('es', ''),
      ],
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (context) => const MyHomePage());
        } else if (settings.name == '/settings') {
          return MaterialPageRoute(builder: (context) => const SettingsPage());
        } else if (settings.name == '/new_game') {
          final args = settings.arguments as NewGameScreenArguments;
          return MaterialPageRoute(
            builder: (context) => NewGameScreen(
              initialFen: args.initialFen,
            ),
          );
        } else if (settings.name == '/new_game_editor') {
          return MaterialPageRoute(builder: (context) {
            final args =
                settings.arguments as NewGamePositionEditorScreenArguments;
            return NewGamePositionEditorScreen(initialFen: args.initialFen);
          });
        } else {
          return MaterialPageRoute(builder: (context) => const MyHomePage());
        }
      },
    );
  }
}
