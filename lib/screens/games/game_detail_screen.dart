import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../services/game_rules_pdf.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../new_game/game_actions_sheet.dart';
import '../new_game/game_rules_screen.dart';

/// Read-first view of a single game — its settings (one card per rule) and,
/// front and center, its rules reminders — with quick access to edit either,
/// or (root owner only) delete it via the app bar menu.
class GameDetailScreen extends StatelessWidget {
  final Game game;
  const GameDetailScreen({super.key, required this.game});

  static String _countDescription(GameRule rule) => switch (rule.countType) {
        CountType.highWins => 'Points — le plus haut gagne',
        CountType.lowWins => 'Points — le plus bas gagne',
        CountType.wins => 'Manches gagnées',
        CountType.ranks => 'Classement',
        CountType.winLoss => 'Victoire / défaite',
      };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // Keep showing the freshest copy (settings/rules might have just been
    // edited) instead of the one passed in when this screen was pushed.
    final current = app.gameById(game.id) ?? game;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(current.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
        actions: [
          IconButton(icon: Icon(Icons.picture_as_pdf_rounded, color: AppColors.ink), tooltip: 'Exporter les règles en PDF', onPressed: () => exportGameRulesPdf(current)),
          IconButton(icon: Icon(Icons.more_vert_rounded, color: AppColors.ink), onPressed: () => showGameActionsSheet(context, app, current)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          FadeSlideIn(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16)),
                  child: Text(current.emoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(current.name, style: dispFont(size: 19, weight: FontWeight.w800, color: AppColors.ink)),
                      Text(current.category, style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: current.hasMultipleRules ? 'Règles de score' : 'Règle de score'),
          for (final (i, rule) in current.rules.indexed)
            FadeSlideIn(
              delay: Duration(milliseconds: 60 + i * 40),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (current.hasMultipleRules) ...[
                      Text(rule.name, style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.accent)),
                      const SizedBox(height: 4),
                    ],
                    Text(_countDescription(rule), style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
                    if (rule.pointLimit != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Limite : ${rule.pointLimit} points', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
                      ),
                    if (rule.multiRound)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Manches multiples activées', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
                      ),
                    if (rule.isRanks && ((rule.topRoles?.isNotEmpty ?? false) || (rule.bottomRoles?.isNotEmpty ?? false))) ...[
                      const SizedBox(height: 8),
                      for (final r in rule.topRoles ?? const <String>[])
                        Text('•  $r', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2)),
                      for (final r in rule.bottomRoles ?? const <String>[])
                        Text('•  $r', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2)),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          SectionHeader(
            title: 'Aide-mémoire',
            actionLabel: 'Modifier',
            onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameRulesScreen(game: current))),
          ),
          if (current.ruleSections.isEmpty)
            EmptyState(emoji: '📖', message: "Aucun aide-mémoire enregistré pour l'instant.")
          else
            for (final (i, section) in current.ruleSections.indexed)
              FadeSlideIn(
                delay: Duration(milliseconds: 100 + i * 40),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section.title, style: bodyFont(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                      const SizedBox(height: 6),
                      for (final rule in section.rules)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('•  ', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.mut)),
                              Expanded(child: Text(rule, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.ink2))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
