import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/game.dart';
import '../models/match.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'avatar.dart';

/// Small pulsing red dot used to mark a match as currently live.
class LiveDot extends StatefulWidget {
  final double size;
  const LiveDot({super.key, this.size = 8});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
      ),
    );
  }
}

/// Best-placed player in a live session so far — highest points, or lowest
/// if the game/unit plays "low wins".
MatchEntry? _leadingEntry(LiveMatchSession session) {
  if (session.entries.isEmpty) return null;
  return session.entries.reduce((a, b) => session.lowWins ? (b.points < a.points ? b : a) : (b.points > a.points ? b : a));
}

/// Compact card for a match currently being scored by someone else in the
/// group — shown in a horizontally scrolling row on the home screen. Tap to
/// open the full live view.
class LiveMatchCard extends StatelessWidget {
  final LiveMatchSession session;
  final Game? game;
  final AppState appState;
  final VoidCallback? onTap;
  const LiveMatchCard({super.key, required this.session, required this.game, required this.appState, this.onTap});

  @override
  Widget build(BuildContext context) {
    final leader = _leadingEntry(session);
    final leaderPlayer = leader != null ? appState.playerById(leader.playerId) : null;
    final players = session.entries.map((e) => appState.playerById(e.playerId)).whereType<AppUser>().toList();

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: onTap,
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: session.held
                  ? [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.mut, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('HORS LIGNE', style: bodyFont(size: 11, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.6)),
                    ]
                  : [
                      const LiveDot(),
                      const SizedBox(width: 6),
                      Text('EN DIRECT', style: bodyFont(size: 11, weight: FontWeight.w800, color: Colors.red, letterSpacing: 0.6)),
                    ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(game?.emoji ?? '🎲', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    game?.name ?? 'Partie',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodyFont(size: 14.5, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Débutée par ${session.startedByName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut),
            ),
            const SizedBox(height: 10),
            if (leaderPlayer != null)
              Row(
                children: [
                  Avatar(initial: leaderPlayer.initial, color: Color(leaderPlayer.color), size: 26, fontSize: 11),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      leaderPlayer.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink),
                    ),
                  ),
                  Text('${leader!.points}', style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.accent)),
                ],
              )
            else
              AvatarCluster(avatars: [for (final p in players.take(3)) (initial: p.initial, color: Color(p.color))]),
          ],
        ),
      ),
    );
  }
}
