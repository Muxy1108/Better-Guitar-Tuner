import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../models/audio_bridge_diagnostics.dart';
import '../models/tuner_settings.dart';
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
                      _SettingsCard(viewModel: viewModel),
                      const SizedBox(height: 12),
                      _ResultSummaryCard(
                        result: result,
                        rawCentsOffset: viewModel.rawCentsOffset,
                        smoothedCentsOffset: viewModel.smoothedCentsOffset,
                      ),
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n.centsMeterLabel,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                            const SizedBox(height: 4),
                            Text(
                              _listeningSummary(l10n, viewModel),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 20),
                            CentsMeter(
                              centsOffset: result.hasDisplayablePitch
                                  ? result.centsOffset
                                  : 0,
                              hasPitch: result.hasDisplayablePitch,
                              displayLabel: _meterDisplayLabel(l10n, result),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DiagnosticsCard(viewModel: viewModel),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _SettingsCard extends StatefulWidget {
  const _SettingsCard({required this.viewModel});

  final TunerViewModel viewModel;

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
  late final TextEditingController _backendController;
  late final TextEditingController _deviceController;

  @override
  void initState() {
    super.initState();
    _backendController = TextEditingController(
      text: widget.viewModel.settings.backend ?? '',
    );
    _deviceController = TextEditingController(
      text: widget.viewModel.settings.device ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _SettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(
      _backendController,
      widget.viewModel.settings.backend ?? '',
    );
    _syncController(
      _deviceController,
      widget.viewModel.settings.device ?? '',
    );
  }

  @override
  void dispose() {
    _backendController.dispose();
    _deviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = widget.viewModel.settings;
    final canEditBridgeTarget =
        widget.viewModel.bridgeKind == AudioBridgeKind.desktopProcess ||
            widget.viewModel.bridgeKind == AudioBridgeKind.mock;

    return _SectionCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          l10n.settingsLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(l10n.settingsSubtitle),
        children: [
          const SizedBox(height: 8),
          _SliderSettingRow(
            label: l10n.a4ReferenceLabel,
            valueLabel: l10n.frequencyValue(
              settings.a4ReferenceHz.toStringAsFixed(1),
            ),
            value: settings.a4ReferenceHz,
            min: 432,
            max: 446,
            divisions: 28,
            onChanged: (value) {
              widget.viewModel.updateSettings(
                settings.copyWith(a4ReferenceHz: value),
              );
            },
          ),
          const SizedBox(height: 12),
          _SliderSettingRow(
            label: l10n.tuningToleranceSettingLabel,
            valueLabel: l10n.centsValue(
              settings.tuningToleranceCents.toStringAsFixed(1),
            ),
            value: settings.tuningToleranceCents,
            min: 2,
            max: 10,
            divisions: 16,
            onChanged: (value) {
              widget.viewModel.updateSettings(
                settings.copyWith(tuningToleranceCents: value),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            l10n.sensitivityLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<TunerSensitivityLevel>(
            segments: [
              ButtonSegment<TunerSensitivityLevel>(
                value: TunerSensitivityLevel.relaxed,
                label: Text(l10n.sensitivityRelaxedLabel),
              ),
              ButtonSegment<TunerSensitivityLevel>(
                value: TunerSensitivityLevel.balanced,
                label: Text(l10n.sensitivityBalancedLabel),
              ),
              ButtonSegment<TunerSensitivityLevel>(
                value: TunerSensitivityLevel.precise,
                label: Text(l10n.sensitivityPreciseLabel),
              ),
            ],
            selected: {settings.sensitivityLevel},
            onSelectionChanged: (selection) {
              widget.viewModel.updateSettings(
                settings.copyWith(sensitivityLevel: selection.first),
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsTextField(
            controller: _backendController,
            label: l10n.bridgeBackendLabel,
            hintText: l10n.settingsBackendHint,
            enabled: canEditBridgeTarget,
            onSubmitted: (value) {
              widget.viewModel.updateSettings(
                settings.copyWith(
                  backend: value.trim(),
                  clearBackend: value.trim().isEmpty,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsTextField(
            controller: _deviceController,
            label: l10n.bridgeDeviceLabel,
            hintText: l10n.settingsDeviceHint,
            enabled: canEditBridgeTarget,
            onSubmitted: (value) {
              widget.viewModel.updateSettings(
                settings.copyWith(
                  device: value.trim(),
                  clearDevice: value.trim().isEmpty,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.mockBridgeOverrideLabel),
            subtitle: Text(l10n.mockBridgeOverrideHelp),
            value: settings.mockBridgeOverride,
            onChanged: (value) {
              widget.viewModel.updateSettings(
                settings.copyWith(mockBridgeOverride: value),
              );
            },
          ),
        ],
      ),
    );
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({required this.viewModel});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final diagnostics = viewModel.bridgeDiagnostics;
    final settings = viewModel.settings;
    final result = viewModel.latestResult;

    return _SectionCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          l10n.bridgeDiagnosticsLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(l10n.diagnosticsSubtitle),
        children: [
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricTile(
                label: l10n.bridgeTypeLabel,
                value: _bridgeKindLabel(l10n, viewModel.bridgeKind),
              ),
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
                label: l10n.pitchStateLabel,
                value: _signalTitle(l10n, viewModel.rawSignalState),
              ),
              _MetricTile(
                label: l10n.rawCentsLabel,
                value: viewModel.latestRawResult.hasDisplayablePitch
                    ? _formatSignedCents(viewModel.rawCentsOffset)
                    : '--',
              ),
              _MetricTile(
                label: l10n.smoothedCentsLabel,
                value: result.hasDisplayablePitch
                    ? _formatSignedCents(viewModel.smoothedCentsOffset)
                    : '--',
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
          if (viewModel.latestRawResult.analysisReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'DSP reason: ${viewModel.latestRawResult.analysisReason}',
            ),
          ],
          if (viewModel.latestRawResult.runnerRejectionReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Runner gate: ${viewModel.latestRawResult.runnerRejectionReason}',
            ),
          ],
          if (viewModel.lastUiSuppressionReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'UI hold: ${viewModel.lastUiSuppressionReason}',
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
  const _ResultSummaryCard({
    required this.result,
    required this.rawCentsOffset,
    required this.smoothedCentsOffset,
  });

  final TuningResultModel result;
  final double rawCentsOffset;
  final double smoothedCentsOffset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final targetNote =
        result.hasTarget ? (result.targetNote ?? l10n.unavailableValue) : '--';
    final frequencyValue = result.hasDisplayablePitch
        ? l10n.frequencyValue(result.pitchFrame.frequencyHz.toStringAsFixed(2))
        : _signalTitle(l10n, result.signalState);
    final centsValue = result.hasDisplayablePitch
        ? _formatSignedCents(smoothedCentsOffset)
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
                label: l10n.rawCentsLabel,
                value: result.hasDisplayablePitch
                    ? _formatSignedCents(rawCentsOffset)
                    : '--',
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
      return l10n.pitchedLabel;
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

String _bridgeKindLabel(AppLocalizations l10n, AudioBridgeKind kind) {
  switch (kind) {
    case AudioBridgeKind.mock:
      return l10n.bridgeTypeMock;
    case AudioBridgeKind.native:
      return l10n.bridgeTypeNative;
    case AudioBridgeKind.desktopProcess:
      return l10n.bridgeTypeDesktop;
  }
}

String _meterDisplayLabel(AppLocalizations l10n, TuningResultModel result) {
  if (!result.hasDisplayablePitch) {
    return l10n.noPitchLabel;
  }
  return l10n.centsValue(_formatSignedNumber(result.centsOffset));
}

String _formatSignedCents(double value) {
  return '${_formatSignedNumber(value)} cents';
}

String _formatSignedNumber(double value) {
  final prefix = value >= 0 ? '+' : '';
  return '$prefix${value.toStringAsFixed(1)}';
}

class _SliderSettingRow extends StatelessWidget {
  const _SliderSettingRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(valueLabel),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  const _SettingsTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool enabled;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      inputFormatters: [
        LengthLimitingTextInputFormatter(120),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
    );
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
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
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
