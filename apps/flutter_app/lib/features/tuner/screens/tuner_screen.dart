import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/tuning_mode.dart';
import '../models/tuning_result.dart';
import '../view_models/tuner_view_model.dart';
import '../widgets/cents_meter.dart';
import '../widgets/status_badge.dart';

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
        final preset = viewModel.selectedPreset;
        final result = viewModel.latestResult;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.appTitle),
          ),
          body: SafeArea(
            child: viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (viewModel.errorMessage != null)
                        _SectionCard(
                          child: Text(
                            '${l10n.errorLabel}: ${viewModel.errorMessage}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.tuningPresetLabel,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: preset?.id,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: viewModel.presets
                                  .map(
                                    (item) => DropdownMenuItem<String>(
                                      value: item.id,
                                      child: Text(item.name),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value != null) {
                                  viewModel.setPresetById(value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.modeLabel,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            SegmentedButton<TunerMode>(
                              segments: [
                                ButtonSegment<TunerMode>(
                                  value: TunerMode.auto,
                                  label: Text(l10n.autoModeLabel),
                                ),
                                ButtonSegment<TunerMode>(
                                  value: TunerMode.manual,
                                  label: Text(l10n.manualModeLabel),
                                ),
                              ],
                              selected: {viewModel.mode},
                              onSelectionChanged: (selection) {
                                viewModel.setMode(selection.first);
                              },
                            ),
                            if (preset != null &&
                                viewModel.mode == TunerMode.manual)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: List<Widget>.generate(
                                    preset.notes.length,
                                    (index) => ChoiceChip(
                                      label: Text(
                                        l10n.stringChipLabel(
                                          index + 1,
                                          preset.notes[index],
                                        ),
                                      ),
                                      selected:
                                          index == viewModel.manualStringIndex,
                                      onSelected: (_) {
                                        viewModel.setManualStringIndex(index);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.listeningLabel,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    viewModel.isListening
                                        ? l10n.mockBridgeRunning
                                        : l10n.listeningStopped,
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () => viewModel.toggleListening(),
                              child: Text(
                                viewModel.isListening
                                    ? l10n.stopListeningLabel
                                    : l10n.startListeningLabel,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ResultSummaryCard(result: result),
                      const SizedBox(height: 12),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.centsMeterLabel,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 20),
                            CentsMeter(
                              centsOffset: result.pitchFrame.hasPitch
                                  ? result.centsOffset
                                  : 0,
                              hasPitch: result.pitchFrame.hasPitch,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _ResultSummaryCard extends StatelessWidget {
  const _ResultSummaryCard({required this.result});

  final TuningResultModel result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final targetNote =
        result.hasTarget ? (result.targetNote ?? l10n.unavailableValue) : '--';
    final frequencyValue = result.pitchFrame.hasPitch
        ? '${result.pitchFrame.frequencyHz.toStringAsFixed(2)} Hz'
        : l10n.noPitchLabel;
    final centsValue = result.pitchFrame.hasPitch
        ? '${result.centsOffset >= 0 ? '+' : ''}${result.centsOffset.toStringAsFixed(1)}'
        : '--';

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.tunerReadingLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusBadge(status: result.status),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricTile(
                label: l10n.targetNoteLabel,
                value: targetNote,
              ),
              _MetricTile(
                label: l10n.detectedFrequencyLabel,
                value: frequencyValue,
              ),
              _MetricTile(
                label: l10n.centsOffsetLabel,
                value: centsValue,
              ),
              _MetricTile(
                label: l10n.tuningStatusLabel,
                value: _statusLabel(l10n, result.status),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, TuningStatus status) {
    switch (status) {
      case TuningStatus.noPitch:
        return l10n.noPitchLabel;
      case TuningStatus.tooLow:
        return l10n.tooLowLabel;
      case TuningStatus.inTune:
        return l10n.inTuneLabel;
      case TuningStatus.tooHigh:
        return l10n.tooHighLabel;
    }
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7DEE1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
