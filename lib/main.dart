import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'settings.dart';
import 'ui/runtime_screen.dart';
import 'ui/theme.dart';

void main() => runApp(const RuntimeSurvivorsApp());

class RuntimeSurvivorsApp extends StatefulWidget {
  const RuntimeSurvivorsApp({super.key, this.settings});
  final GameSettings? settings;
  @override
  State<RuntimeSurvivorsApp> createState() => _RuntimeSurvivorsAppState();
}

class _RuntimeSurvivorsAppState extends State<RuntimeSurvivorsApp> {
  late final settings = widget.settings ?? GameSettings();
  @override
  void initState() {
    super.initState();
    if (widget.settings == null) unawaited(settings.load());
  }

  @override
  void dispose() {
    if (widget.settings == null) settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => MaterialApp(
      title: 'Runtime Survivors',
      debugShowCheckedModeBanner: false,
      locale: Locale(settings.language),
      supportedLocales: const [Locale('ja'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: gameTheme,
      home: RuntimeScreen(settings: settings),
    ),
  );
}
