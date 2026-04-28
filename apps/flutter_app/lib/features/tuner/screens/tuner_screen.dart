import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../view_models/tuner_view_model.dart';
import '../widgets/tuner_panels.dart';

class TunerScreen extends StatelessWidget {
  const TunerScreen({
    required this.viewModel,
    super.key,
  });

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.appTitle),
          ),
          body: SafeArea(
            child: viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _TunerDashboard(viewModel: viewModel),
          ),
        );
      },
    );
  }
}

class _TunerDashboard extends StatelessWidget {
  const _TunerDashboard({required this.viewModel});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isThreeColumn = constraints.maxWidth >= 1120;
        final isTwoColumn = constraints.maxWidth >= 760;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isThreeColumn ? 24 : 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (TunerAlerts.hasAlerts(viewModel)) ...[
                    TunerAlerts(viewModel: viewModel),
                    const SizedBox(height: 16),
                  ],
                  if (isThreeColumn)
                    _ThreeColumnLayout(viewModel: viewModel)
                  else if (isTwoColumn)
                    _TwoColumnLayout(viewModel: viewModel)
                  else
                    _SingleColumnLayout(viewModel: viewModel),
                  const SizedBox(height: 16),
                  _BottomArea(
                    viewModel: viewModel,
                    useColumns: isTwoColumn,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThreeColumnLayout extends StatelessWidget {
  const _ThreeColumnLayout({required this.viewModel});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 312,
          child: TunerControlPanel(viewModel: viewModel),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: MainMeterPanel(viewModel: viewModel),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 328,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DiagnosticsPanel(viewModel: viewModel),
              const SizedBox(height: 16),
              SignalLevelPanel(viewModel: viewModel),
            ],
          ),
        ),
      ],
    );
  }
}

class _TwoColumnLayout extends StatelessWidget {
  const _TwoColumnLayout({required this.viewModel});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MainMeterPanel(viewModel: viewModel),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TunerControlPanel(viewModel: viewModel),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SignalLevelPanel(viewModel: viewModel),
                  const SizedBox(height: 16),
                  DiagnosticsPanel(viewModel: viewModel),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SingleColumnLayout extends StatelessWidget {
  const _SingleColumnLayout({required this.viewModel});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MainMeterPanel(viewModel: viewModel),
        const SizedBox(height: 16),
        TunerControlPanel(viewModel: viewModel),
        const SizedBox(height: 16),
        SignalLevelPanel(viewModel: viewModel),
        const SizedBox(height: 16),
        DiagnosticsPanel(viewModel: viewModel),
      ],
    );
  }
}

class _BottomArea extends StatelessWidget {
  const _BottomArea({
    required this.viewModel,
    required this.useColumns,
  });

  final TunerViewModel viewModel;
  final bool useColumns;

  @override
  Widget build(BuildContext context) {
    final notes = TuningNotesPanel(viewModel: viewModel);
    final tips = TuningTipsPanel(viewModel: viewModel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (useColumns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: notes),
              const SizedBox(width: 16),
              Expanded(child: tips),
            ],
          )
        else ...[
          notes,
          const SizedBox(height: 16),
          tips,
        ],
        const SizedBox(height: 16),
        TunerSettingsPanel(viewModel: viewModel),
        const SizedBox(height: 12),
        FooterStatusBar(viewModel: viewModel),
      ],
    );
  }
}
