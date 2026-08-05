import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/match.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/match_card.dart';
import 'match_detail_screen.dart';

/// One history row: either a single standalone match, or every leg of a
/// "best of N" series (already-sorted, sharing a `seriesId`) collapsed into
/// one grouped [SeriesMatchCard].
class _HistoryItem {
  final List<GameMatch> legs;
  const _HistoryItem(this.legs);

  bool get isSeries => legs.first.seriesId != null;
  String get gameId => legs.first.gameId;
  DateTime get sortKey => legs.map((m) => m.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
}

List<_HistoryItem> _groupHistoryItems(List<GameMatch> matches) {
  final seriesGroups = <String, List<GameMatch>>{};
  final items = <_HistoryItem>[];
  for (final m in matches) {
    final sid = m.seriesId;
    if (sid == null) {
      items.add(_HistoryItem([m]));
    } else {
      seriesGroups.putIfAbsent(sid, () => []).add(m);
    }
  }
  for (final legs in seriesGroups.values) {
    legs.sort((a, b) => (a.seriesGame ?? 0).compareTo(b.seriesGame ?? 0));
    items.add(_HistoryItem(legs));
  }
  items.sort((a, b) => b.sortKey.compareTo(a.sortKey));
  return items;
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final matches = app.viewMatches;
    final stats = app.groupStats;
    final items = _groupHistoryItems(matches);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 116),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(eyebrow: '${stats['parties']} parties', title: 'Historique'),
          if (items.isEmpty)
            const EmptyState(emoji: '🗂️', message: 'Aucune partie enregistrée pour l\'instant.')
          else
            for (final (i, item) in items.indexed)
              Builder(builder: (context) {
                final g = app.gameById(item.gameId);
                if (g == null) return const SizedBox.shrink();
                return FadeSlideIn(
                  delay: Duration(milliseconds: i * 40),
                  child: item.isSeries
                      ? SeriesMatchCard(
                          game: g,
                          legs: item.legs,
                          appState: app,
                          onTapLeg: (leg) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailScreen(game: g, match: leg, appState: app))),
                        )
                      : MatchCard(
                          game: g,
                          match: item.legs.single,
                          appState: app,
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => MatchDetailScreen(game: g, match: item.legs.single, appState: app))),
                        ),
                );
              }),
        ],
      ),
    );
  }
}
