import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../models/audio_bridge_diagnostics.dart';
import '../models/tuner_settings.dart';
import '../models/tuning_mode.dart';
import '../models/tuning_preset.dart';
import '../models/tuning_result.dart';
import '../services/audio_bridge_service.dart';
import '../view_models/tuner_view_model.dart';
import 'cents_meter.dart';
import 'status_badge.dart';

class TunerAlerts extends StatelessWidget {
  const TunerAlerts({required this.viewModel, super.key});

  final TunerViewModel viewModel;

  static bool hasAlerts(TunerViewModel viewModel) {
    return viewModel.errorMessage != null ||
        viewModel.permissionState == AudioPermissionState.denied ||
        viewModel.listeningErrorMessage != null ||
        (viewModel.isListening &&
            viewModel.latestResult.signalState != TuningSignalState.pitched);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = viewModel.latestResult;
    final diagnostics = viewModel.bridgeDiagnostics;
    final alerts = <Widget>[];

    if (viewModel.errorMessage != null) {
      alerts.add(
        _StateNotice(
          title: l10n.errorLabel,
          message: viewModel.errorMessage!,
          isError: true,
        ),
      );
    }
    if (viewModel.permissionState == AudioPermissionState.denied) {
      alerts.add(
        _StateNotice(
          title: l10n.microphonePermissionDeniedTitle,
          message: l10n.microphonePermissionDeniedMessage,
          isError: true,
        ),
      );
    }
    if (viewModel.listeningErrorMessage != null) {
      alerts.add(
        _StateNotice(
          title: l10n.listeningFailureTitle,
          message: viewModel.listeningErrorMessage!,
          isError: true,
        ),
      );
    }
    if (viewModel.isListening &&
        result.signalState != TuningSignalState.pitched) {
      alerts.add(
        _StateNotice(
          title: _signalTitle(l10n, result.signalState),
          message: _signalMessage(l10n, result.signalState, diagnostics.state),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _withVerticalSpacing(alerts, 12),
    );
  }
}

class TunerControlPanel extends StatelessWidget {
  const TunerControlPanel({required this.viewModel, super.key});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final preset = viewModel.selectedPreset;
    final settings = viewModel.settings;

    return TunerSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TunerSectionTitle(
            icon: Icons.tune_outlined,
            label: l10n.tuningPresetLabel,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: preset?.id,
            isExpanded: true,
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
          const SizedBox(height: 22),
          TunerSectionTitle(
            icon: Icons.speed_outlined,
            label: l10n.modeLabel,
          ),
          const SizedBox(height: 10),
          SegmentedButton<TunerMode>(
            showSelectedIcon: false,
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
          const SizedBox(height: 22),
          TunerSectionTitle(
            icon: Icons.queue_music_outlined,
            label: l10n.manualStringLabel,
          ),
          const SizedBox(height: 10),
          _ManualStringSelector(
            preset: preset,
            selectedIndex: viewModel.manualStringIndex,
            enabled: viewModel.mode == TunerMode.manual,
            onSelected: viewModel.setManualStringIndex,
          ),
          const SizedBox(height: 22),
          TunerSectionTitle(
            icon: Icons.music_note_outlined,
            label: l10n.a4ReferenceLabel,
          ),
          const SizedBox(height: 6),
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
              viewModel.updateSettings(
                settings.copyWith(a4ReferenceHz: value),
              );
            },
          ),
          const SizedBox(height: 18),
          TunerSectionTitle(
            icon: Icons.hearing_outlined,
            label: l10n.sensitivityLabel,
          ),
          const SizedBox(height: 10),
          SegmentedButton<TunerSensitivityLevel>(
            showSelectedIcon: false,
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
              viewModel.updateSettings(
                settings.copyWith(sensitivityLevel: selection.first),
              );
            },
          ),
        ],
      ),
    );
  }
}

class MainMeterPanel extends StatelessWidget {
  const MainMeterPanel({required this.viewModel, super.key});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = viewModel.latestResult;
    final preset = viewModel.selectedPreset;
    final scheme = Theme.of(context).colorScheme;

    return TunerSectionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TunerSectionTitle(
                  icon: Icons.multiline_chart_outlined,
                  label: l10n.centsMeterLabel,
                  large: true,
                ),
              ),
              const SizedBox(width: 12),
              _ListeningButton(viewModel: viewModel),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _listeningSummary(l10n, viewModel),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 244,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _WaveformPainter(colorScheme: scheme),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 8,
                  child: Icon(
                    Icons.music_note_outlined,
                    size: 34,
                    color: scheme.primary.withValues(alpha: 0.10),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 18,
                  child: Icon(
                    Icons.graphic_eq_outlined,
                    size: 38,
                    color: scheme.tertiary.withValues(alpha: 0.10),
                  ),
                ),
                CentsMeter(
                  centsOffset:
                      result.hasDisplayablePitch ? result.centsOffset : 0,
                  hasPitch: result.hasDisplayablePitch,
                  displayLabel: _meterDisplayLabel(l10n, result),
                  height: 218,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _CurrentReadingStrip(result: result),
          const SizedBox(height: 18),
          _StringShortcutGrid(
            preset: preset,
            viewModel: viewModel,
          ),
        ],
      ),
    );
  }
}

class DiagnosticsPanel extends StatelessWidget {
  const DiagnosticsPanel({required this.viewModel, super.key});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final diagnostics = viewModel.bridgeDiagnostics;
    final settings = viewModel.settings;
    final result = viewModel.latestResult;
    final rawResult = viewModel.latestRawResult;

    final metrics = [
      _MetricData(
        label: l10n.bridgeTypeLabel,
        value: _bridgeKindLabel(l10n, viewModel.bridgeKind),
      ),
      _MetricData(
        label: l10n.bridgeStateLabel,
        value: _bridgeStateLabel(l10n, diagnostics.state),
      ),
      _MetricData(
        label: l10n.pitchStateLabel,
        value: _signalTitle(l10n, viewModel.rawSignalState),
      ),
      _MetricData(
        label: l10n.rawCentsLabel,
        value: rawResult.hasDisplayablePitch
            ? _formatSignedCents(l10n, viewModel.rawCentsOffset)
            : '--',
      ),
      _MetricData(
        label: l10n.smoothedCentsLabel,
        value: result.hasDisplayablePitch
            ? _formatSignedCents(l10n, viewModel.smoothedCentsOffset)
            : '--',
      ),
      _MetricData(
        label: l10n.bridgeExitCodeLabel,
        value: diagnostics.lastProcessExitCode?.toString() ?? '--',
      ),
      _MetricData(
        label: l10n.bridgeBackendLabel,
        value: diagnostics.backend ?? settings.backend ?? '--',
      ),
      _MetricData(
        label: l10n.bridgeDeviceLabel,
        value: diagnostics.device ?? settings.device ?? '--',
      ),
    ];

    return TunerSectionCard(
      title: l10n.bridgeDiagnosticsLabel,
      subtitle: l10n.diagnosticsSubtitle,
      icon: Icons.monitor_heart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MetricWrap(metrics: metrics),
          if (diagnostics.lastError != null) ...[
            const SizedBox(height: 12),
            _DiagnosticLine(
              label: l10n.bridgeLastErrorLabel,
              value: diagnostics.lastError!,
              isError: true,
            ),
          ],
          if (rawResult.analysisReason != null) ...[
            const SizedBox(height: 8),
            _DiagnosticLine(
              label: 'DSP reason',
              value: rawResult.analysisReason!,
            ),
          ],
          if (rawResult.runnerRejectionReason != null) ...[
            const SizedBox(height: 8),
            _DiagnosticLine(
              label: 'Runner gate',
              value: rawResult.runnerRejectionReason!,
            ),
          ],
          if (viewModel.lastUiSuppressionReason != null) ...[
            const SizedBox(height: 8),
            _DiagnosticLine(
              label: 'UI hold',
              value: viewModel.lastUiSuppressionReason!,
            ),
          ],
          if (diagnostics.stderrTail.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DiagnosticLine(
              label: l10n.bridgeStderrLabel,
              value: diagnostics.stderrTail.join(' | '),
            ),
          ],
        ],
      ),
    );
  }
}

class SignalLevelPanel extends StatelessWidget {
  const SignalLevelPanel({required this.viewModel, super.key});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = viewModel.latestResult;
    final scheme = Theme.of(context).colorScheme;
    final level = result.hasDisplayablePitch
        ? (result.pitchFrame.confidence ?? 0).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final color = switch (result.signalState) {
      TuningSignalState.pitched => scheme.primary,
      TuningSignalState.weakSignal => const Color(0xFFB7791F),
      TuningSignalState.noPitch => scheme.outline,
    };

    return TunerSectionCard(
      title: l10n.signalLevelLabel,
      icon: Icons.graphic_eq_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _signalTitle(l10n, result.signalState),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${(level * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: level,
              minHeight: 10,
              color: color,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class TuningNotesPanel extends StatelessWidget {
  const TuningNotesPanel({required this.viewModel, super.key});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final preset = viewModel.selectedPreset;
    final result = viewModel.latestResult;
    final targetIndex = result.targetStringIndex ?? viewModel.manualStringIndex;
    final targetNote = result.hasTarget
        ? result.targetNote ?? l10n.unavailableValue
        : l10n.unavailableValue;

    return TunerSectionCard(
      title: l10n.tuningNotesLabel,
      icon: Icons.library_music_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preset != null) ...[
            Text(
              preset.name,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(
                preset.notes.length,
                (index) {
                  final selected = index == targetIndex;
                  return Chip(
                    label: Text(preset.notes[index]),
                    avatar: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    side: BorderSide(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          _KeyValueLine(
            label: l10n.targetNoteLabel,
            value: targetNote,
          ),
          const SizedBox(height: 8),
          _KeyValueLine(
            label: l10n.tuningStatusLabel,
            value: _statusLabel(l10n, result.status),
          ),
        ],
      ),
    );
  }
}

class TuningTipsPanel extends StatelessWidget {
  const TuningTipsPanel({required this.viewModel, super.key});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = viewModel.latestResult;
    final message = switch (result.signalState) {
      TuningSignalState.noPitch => viewModel.isListening
          ? l10n.noPitchListeningMessage
          : l10n.noPitchMessage,
      TuningSignalState.weakSignal => l10n.weakSignalMessage,
      TuningSignalState.pitched => _statusLabel(l10n, result.status),
    };

    return TunerSectionCard(
      title: l10n.tuningTipsLabel,
      icon: Icons.lightbulb_outline,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _tipIcon(result),
            color: _statusColor(context, result.status, result.signalState),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class TunerSettingsPanel extends StatefulWidget {
  const TunerSettingsPanel({required this.viewModel, super.key});

  final TunerViewModel viewModel;

  @override
  State<TunerSettingsPanel> createState() => _TunerSettingsPanelState();
}

class _TunerSettingsPanelState extends State<TunerSettingsPanel> {
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
  void didUpdateWidget(covariant TunerSettingsPanel oldWidget) {
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

    return TunerSectionCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.settings_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          l10n.settingsLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(l10n.settingsSubtitle),
        children: [
          const SizedBox(height: 10),
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
          const SizedBox(height: 14),
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

class FooterStatusBar extends StatelessWidget {
  const FooterStatusBar({required this.viewModel, super.key});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final diagnostics = viewModel.bridgeDiagnostics;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _FooterItem(
                label: l10n.bridgeStateLabel,
                value: _bridgeStateLabel(l10n, diagnostics.state),
              ),
              _FooterItem(
                label: l10n.bridgeTypeLabel,
                value: _bridgeKindLabel(l10n, viewModel.bridgeKind),
              ),
              _FooterItem(
                label: l10n.a4ReferenceLabel,
                value: l10n.frequencyValue(
                  viewModel.settings.a4ReferenceHz.toStringAsFixed(1),
                ),
              ),
            ],
          ),
          if (diagnostics.stderrTail.isNotEmpty) ...[
            const SizedBox(height: 8),
            _FooterItem(
              label: l10n.bridgeStderrLabel,
              value: diagnostics.stderrTail.join(' | '),
            ),
          ],
        ],
      ),
    );
  }
}

class TunerSectionCard extends StatelessWidget {
  const TunerSectionCard({
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              TunerSectionTitle(
                icon: icon ?? Icons.circle_outlined,
                label: title!,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class TunerSectionTitle extends StatelessWidget {
  const TunerSectionTitle({
    required this.icon,
    required this.label,
    this.large = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = large
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.titleMedium;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: large ? 36 : 30,
          height: large ? 36 : 30,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: scheme.primary,
            size: large ? 21 : 18,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: style?.copyWith(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ListeningButton extends StatelessWidget {
  const _ListeningButton({required this.viewModel});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isListening = viewModel.isListening;

    if (isListening) {
      return OutlinedButton.icon(
        onPressed: viewModel.toggleListening,
        icon: const Icon(Icons.stop_circle_outlined),
        label: Text(l10n.stopListeningLabel),
      );
    }

    return FilledButton.icon(
      onPressed: viewModel.toggleListening,
      icon: const Icon(Icons.play_arrow_rounded),
      label: Text(l10n.startListeningLabel),
    );
  }
}

class _ManualStringSelector extends StatelessWidget {
  const _ManualStringSelector({
    required this.preset,
    required this.selectedIndex,
    required this.enabled,
    required this.onSelected,
  });

  final TuningPreset? preset;
  final int selectedIndex;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notes = preset?.notes ?? const <String>[];
    if (notes.isEmpty) {
      return Text(
        '--',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(
        notes.length,
        (index) => ChoiceChip(
          label: Text(l10n.stringChipLabel(index + 1, notes[index])),
          selected: index == selectedIndex,
          onSelected: enabled ? (_) => onSelected(index) : null,
        ),
      ),
    );
  }
}

class _CurrentReadingStrip extends StatelessWidget {
  const _CurrentReadingStrip({required this.result});

  final TuningResultModel result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentNote = result.hasDisplayablePitch
        ? result.pitchFrame.noteName ??
            result.targetNote ??
            l10n.unavailableValue
        : result.targetNote ?? '--';
    final frequency = result.hasDisplayablePitch
        ? l10n.frequencyValue(result.pitchFrame.frequencyHz.toStringAsFixed(2))
        : '--';
    final cents = result.hasDisplayablePitch
        ? _formatSignedCents(l10n, result.centsOffset)
        : '--';

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ReadingTile(
          label: l10n.currentNoteLabel,
          value: currentNote,
          emphasized: true,
        ),
        _ReadingTile(
          label: l10n.detectedFrequencyLabel,
          value: frequency,
        ),
        _ReadingTile(
          label: l10n.centsOffsetLabel,
          value: cents,
        ),
        StatusBadge(
          status: result.status,
          signalState: result.signalState,
        ),
      ],
    );
  }
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.primaryContainer.withValues(alpha: 0.40)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: emphasized
              ? scheme.primary.withValues(alpha: 0.45)
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: (emphasized
                    ? Theme.of(context).textTheme.headlineSmall
                    : Theme.of(context).textTheme.titleMedium)
                ?.copyWith(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StringShortcutGrid extends StatelessWidget {
  const _StringShortcutGrid({
    required this.preset,
    required this.viewModel,
  });

  final TuningPreset? preset;
  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final notes = preset?.notes ?? const <String>[];
    if (notes.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeIndex = viewModel.latestResult.targetStringIndex ??
        (viewModel.mode == TunerMode.manual ? viewModel.manualStringIndex : -1);

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final availableWidth = math.max(0.0, constraints.maxWidth);
        final columns = availableWidth >= 560
            ? 6
            : availableWidth >= 360
                ? 3
                : 2;
        final width = math.max(
          0.0,
          (availableWidth - spacing * (columns - 1)) / columns,
        );

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List<Widget>.generate(
            notes.length,
            (index) => SizedBox(
              width: width,
              child: _StringShortcutCard(
                index: index,
                note: notes[index],
                selected: index == activeIndex,
                onTap: () async {
                  if (viewModel.mode != TunerMode.manual) {
                    await viewModel.setMode(TunerMode.manual);
                  }
                  await viewModel.setManualStringIndex(index);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StringShortcutCard extends StatelessWidget {
  const _StringShortcutCard({
    required this.index,
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = _stringPastel(index);
    final borderColor =
        selected ? scheme.primary : _stringBorder(index, scheme);

    return Material(
      color: selected
          ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.10), baseColor)
          : baseColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: borderColor,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                note,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _MetricWrap extends StatelessWidget {
  const _MetricWrap({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final availableWidth = math.max(0.0, constraints.maxWidth);
        final columns = availableWidth >= 300 ? 2 : 1;
        final tileWidth = math.max(
          0.0,
          (availableWidth - spacing * (columns - 1)) / columns,
        );

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: tileWidth,
                  child: _MetricTile(
                    label: metric.label,
                    value: metric.value,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DiagnosticLine extends StatelessWidget {
  const _DiagnosticLine({
    required this.label,
    required this.value,
    this.isError = false,
  });

  final String label;
  final String value;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isError ? scheme.error : scheme.onSurfaceVariant,
          ),
    );
  }
}

class _StateNotice extends StatelessWidget {
  const _StateNotice({
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

    return TunerSectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
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

class _KeyValueLine extends StatelessWidget {
  const _KeyValueLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}

class _FooterItem extends StatelessWidget {
  const _FooterItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;

    for (var wave = 0; wave < 3; wave += 1) {
      final path = Path();
      final amplitude = 10.0 + wave * 4;
      final yBase = size.height * (0.42 + wave * 0.08);
      final phase = wave * math.pi / 3;
      for (var x = 0.0; x <= size.width; x += 6) {
        final y = yBase +
            math.sin((x / size.width) * math.pi * 4 + phase) * amplitude;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      paint.color = (wave.isEven ? colorScheme.primary : colorScheme.tertiary)
          .withValues(alpha: 0.08);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme;
  }
}

List<Widget> _withVerticalSpacing(List<Widget> widgets, double spacing) {
  if (widgets.length < 2) {
    return widgets;
  }

  return [
    for (var index = 0; index < widgets.length; index += 1) ...[
      if (index > 0) SizedBox(height: spacing),
      widgets[index],
    ],
  ];
}

Color _stringPastel(int index) {
  const colors = [
    Color(0xFFFFF7ED),
    Color(0xFFF0FDF4),
    Color(0xFFEFF6FF),
    Color(0xFFFEFCE8),
    Color(0xFFFDF2F8),
    Color(0xFFF5F3FF),
  ];
  return colors[index % colors.length];
}

Color _stringBorder(int index, ColorScheme scheme) {
  const colors = [
    Color(0xFFF4C38A),
    Color(0xFFA7D7B7),
    Color(0xFFAFC7EA),
    Color(0xFFE5D88C),
    Color(0xFFE9B7D2),
    Color(0xFFC9BDF4),
  ];
  return Color.alphaBlend(
    scheme.outlineVariant.withValues(alpha: 0.30),
    colors[index % colors.length],
  );
}

IconData _tipIcon(TuningResultModel result) {
  if (result.signalState == TuningSignalState.weakSignal) {
    return Icons.signal_cellular_alt_1_bar;
  }
  if (result.status == TuningStatus.inTune) {
    return Icons.check_circle_outline;
  }
  return Icons.info_outline;
}

Color _statusColor(
  BuildContext context,
  TuningStatus status,
  TuningSignalState signalState,
) {
  final scheme = Theme.of(context).colorScheme;
  if (signalState == TuningSignalState.weakSignal) {
    return const Color(0xFFB7791F);
  }
  return switch (status) {
    TuningStatus.inTune => scheme.primary,
    TuningStatus.tooLow => const Color(0xFF0E7490),
    TuningStatus.tooHigh => const Color(0xFFB45309),
    TuningStatus.noPitch => scheme.onSurfaceVariant,
  };
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

String _formatSignedCents(AppLocalizations l10n, double value) {
  return l10n.centsValue(_formatSignedNumber(value));
}

String _formatSignedNumber(double value) {
  final prefix = value >= 0 ? '+' : '';
  return '$prefix${value.toStringAsFixed(1)}';
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
