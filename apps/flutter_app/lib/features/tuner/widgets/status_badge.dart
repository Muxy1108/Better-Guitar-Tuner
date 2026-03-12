import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/tuning_result.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.status,
    required this.signalState,
    super.key,
  });

  final TuningStatus status;
  final TuningSignalState signalState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, label) = switch ((signalState, status)) {
      (TuningSignalState.weakSignal, _) => (
          const Color(0xFFFDE68A),
          const Color(0xFF854D0E),
          l10n.weakSignalLabel,
        ),
      (_, TuningStatus.noPitch) => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          l10n.noPitchLabel,
        ),
      (_, TuningStatus.tooLow) => (
          const Color(0xFFD7F0F7),
          const Color(0xFF155E75),
          l10n.tooLowLabel,
        ),
      (_, TuningStatus.inTune) => (
          const Color(0xFFD9F5DF),
          const Color(0xFF166534),
          l10n.inTuneLabel,
        ),
      (_, TuningStatus.tooHigh) => (
          const Color(0xFFFCE7D0),
          const Color(0xFF9A3412),
          l10n.tooHighLabel,
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: Text(
            label,
            key: ValueKey<String>(label),
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
