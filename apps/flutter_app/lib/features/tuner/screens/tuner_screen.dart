import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/audio_bridge_diagnostics.dart';
import '../models/tuning_mode.dart';
import '../models/tuning_result.dart';
import '../services/audio_bridge_service.dart';
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
        final diagnostics = viewModel.bridgeDiagnostics;

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
                      if (viewModel.permissionState ==
                          AudioPermissionState.denied)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _StateCard(
                            title: l10n.microphonePermissionDeniedTitle,
                            message: l10n.microphonePermissionDeniedMessage,
                          ),
                        ),
                      if (viewModel.listeningErrorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _StateCard(
                            title: l10n.listeningFailureTitle,
                            message: viewModel.listeningErrorMessage!,
                            isError: true,
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
                                    _listeningSummary(l10n, viewModel),
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
                      _BridgeDiagnosticsCard(viewModel: viewModel),
                      const SizedBox(height: 12),
                      _ResultSummaryCard(result: result),
                      if (viewModel.isListening &&
                          result.signalState != TuningSignalState.pitched)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _StateCard(
                            title: _signalTitle(l10n, result.signalState),
                            message: _signalMessage(
                              l10n,
                              result.signalState,
                              diagnostics.state,
                            ),
                          ),
                        ),
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
                              centsOffset: result.hasUsablePitch
                                  ? result.centsOffset
                                  : 0,
                              hasPitch: result.hasUsablePitch,
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

class _BridgeDiagnosticsCard extends StatelessWidget {
  const _BridgeDiagnosticsCard({required this.viewModel});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final diagnostics = viewModel.bridgeDiagnostics;
    final settings = viewModel.settings;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.bridgeDiagnosticsLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricTile(
                label: l10n.bridgeStateLabel,
                value: _bridgeStateLabel(l10n, diagnostics.state),
              ),
              _MetricTile(
                label: l10n.bridgeBackendLabel,
                value: diagnostics.backend ?? settings.backend ?? '--',
              ),
              _MetricTile(
                label: l10n.bridgeDeviceLabel,
                value: diagnostics.device ?? settings.device ?? '--',
              ),
              _MetricTile(
                label: l10n.bridgeExitCodeLabel,
                value: diagnostics.lastProcessExitCode?.toString() ?? '--',
              ),
            ],
          ),
          if (diagnostics.lastError != null) ...[
            const SizedBox(height: 12),
            Text(
              '${l10n.bridgeLastErrorLabel}: ${diagnostics.lastError}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (diagnostics.stderrTail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${l10n.bridgeStderrLabel}: ${diagnostics.stderrTail.join(' | ')}',
            ),
          ],
        ],
      ),
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
    final frequencyValue = result.hasUsablePitch
        ? '${result.pitchFrame.frequencyHz.toStringAsFixed(2)} Hz'
        : _signalTitle(l10n, result.signalState);
    final centsValue = result.hasUsablePitch
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
              StatusBadge(
                status: result.status,
                signalState: result.signalState,
              ),
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

String _listeningSummary(AppLocalizations l10n, TunerViewModel viewModel) {
  if (viewModel.permissionState == AudioPermissionState.denied) {
    return l10n.microphonePermissionDeniedMessage;
  }

  switch (viewModel.bridgeDiagnostics.state) {
    case AudioBridgeState.starting:
      return l10n.listeningPreparing;
    case AudioBridgeState.stopping:
      return l10n.listeningStopping;
    case AudioBridgeState.error:
      return viewModel.listeningErrorMessage ?? l10n.listeningFailureMessage;
    case AudioBridgeState.idle:
      return l10n.listeningStopped;
    case AudioBridgeState.listening:
      switch (viewModel.bridgeKind) {
        case AudioBridgeKind.native:
          return l10n.nativeBridgeRunning;
        case AudioBridgeKind.desktopProcess:
          return l10n.desktopBridgeRunning;
        case AudioBridgeKind.mock:
          return l10n.mockBridgeRunning;
      }
  }
}

String _signalTitle(AppLocalizations l10n, TuningSignalState signalState) {
  switch (signalState) {
    case TuningSignalState.weakSignal:
      return l10n.weakSignalLabel;
    case TuningSignalState.pitched:
      return l10n.tunerReadingLabel;
    case TuningSignalState.noPitch:
      return l10n.noPitchLabel;
  }
}

String _signalMessage(
  AppLocalizations l10n,
  TuningSignalState signalState,
  AudioBridgeState bridgeState,
) {
  switch (signalState) {
    case TuningSignalState.weakSignal:
      return l10n.weakSignalDetailedMessage;
    case TuningSignalState.pitched:
      return l10n.listeningLabel;
    case TuningSignalState.noPitch:
      if (bridgeState == AudioBridgeState.starting) {
        return l10n.listeningPreparing;
      }
      return l10n.noPitchListeningMessage;
  }
}

String _bridgeStateLabel(
  AppLocalizations l10n,
  AudioBridgeState state,
) {
  switch (state) {
    case AudioBridgeState.idle:
      return l10n.bridgeStateIdle;
    case AudioBridgeState.starting:
      return l10n.bridgeStateStarting;
    case AudioBridgeState.listening:
      return l10n.bridgeStateListening;
    case AudioBridgeState.stopping:
      return l10n.bridgeStateStopping;
    case AudioBridgeState.error:
      return l10n.bridgeStateError;
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

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.title,
    required this.message,
    this.isError = false,
  });

  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isError ? scheme.error : scheme.primary;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                ),
          ),
          const SizedBox(height: 8),
          Text(message),
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
