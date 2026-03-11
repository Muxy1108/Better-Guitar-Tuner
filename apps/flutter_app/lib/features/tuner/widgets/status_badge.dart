import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/tuning_result.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.status,
    super.key,
  });

  final TuningStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, label) = switch (status) {
      TuningStatus.noPitch => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          l10n.noPitchLabel,
        ),
      TuningStatus.tooLow => (
          const Color(0xFFD7F0F7),
          const Color(0xFF155E75),
          l10n.tooLowLabel,
        ),
      TuningStatus.inTune => (
          const Color(0xFFD9F5DF),
          const Color(0xFF166534),
          l10n.inTuneLabel,
        ),
      TuningStatus.tooHigh => (
          const Color(0xFFFCE7D0),
          const Color(0xFF9A3412),
          l10n.tooHighLabel,
        ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
