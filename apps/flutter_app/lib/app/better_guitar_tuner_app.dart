import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/tuner/screens/tuner_screen.dart';
import '../features/tuner/view_models/tuner_view_model.dart';
import '../l10n/app_localizations.dart';

class BetterGuitarTunerApp extends StatelessWidget {
  const BetterGuitarTunerApp({
    required this.viewModel,
    super.key,
  });

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E8B57),
    );

    return MaterialApp(
      title: 'Better Guitar Tuner',
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF6F8F6),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF6F8F6),
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          margin: EdgeInsets.zero,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE1E8E3)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: colorScheme.primary,
          thumbColor: colorScheme.primary,
        ),
        useMaterial3: true,
      ),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _AppShell(viewModel: viewModel),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell({required this.viewModel});

  final TunerViewModel viewModel;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.initialize();
  }

  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TunerScreen(viewModel: widget.viewModel);
  }
}
