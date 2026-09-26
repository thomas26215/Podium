import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

/// Replaces tournament content while offline — tournaments are online-only
/// for now (see `AppState._rejectTournamentOffline`).
class TournamentsOfflineNotice extends StatelessWidget {
  /// A single-line banner (home section, new-game sheet) rather than the
  /// full-screen version (tournament screens).
  final bool compact;
  const TournamentsOfflineNotice({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final banner = Container(
      width: compact ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.mut),
          const SizedBox(width: 10),
          Flexible(
            child: Text(AppState.tournamentsOfflineMessage, style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.mut)),
          ),
        ],
      ),
    );
    if (compact) return banner;
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: banner));
  }
}
