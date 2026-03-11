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
    return MaterialApp(
      title: 'Better Guitar Tuner',
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: const Color(0xFFF4F7F8),
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
