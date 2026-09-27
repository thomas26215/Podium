import 'package:flutter/material.dart';

import '../models/game.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Everything there is to know about a game, laid out read-only: header,
/// themes, one card per scoring rule, the per-player pick, the match setup and the rules
/// reminders. Shared by a catalog game's detail screen and the library's
/// preview before import, so both always show the same thing.
///
/// [hero] swaps the compact header row for a large centered one (the
/// library preview, where the game is still being discovered).
/// [onEditReminders] adds a "Modifier" action on the reminders header —
/// left null where they can't be edited (a library game not imported yet).
class GameOverview extends StatelessWidget {
  final Game game;
  final bool hero;
  final VoidCallback? onEditReminders;
  const GameOverview({super.key, required this.game, this.hero = false, this.onEditReminders});

  static String countDescription(GameRule rule) => switch (rule.countType) {
        CountType.highWins => 'Points — le plus haut gagne',
        CountType.lowWins => 'Points — le plus bas gagne',
        CountType.wins => 'Manches gagnées',
        CountType.ranks => 'Classement',
        CountType.winLoss => 'Victoire / défaite',
        CountType.time => 'Temps — le plus rapide gagne',
      };

  @override
  Widget build(BuildContext context) {
    final subtitle = game.playersLabel == null ? game.category : '${game.category} · ${game.playersLabel}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(child: hero ? _HeroHeader(game: game, subtitle: subtitle) : _CompactHeader(game: game, subtitle: subtitle)),
        if (game.followsLibrary) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.sync_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mis à jour avec la bibliothèque, tant que vous ne le modifiez pas',
                  style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.accent),
                ),
              ),
            ],
          ),
        ],
        if (game.themeTags.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            alignment: hero ? WrapAlignment.center : WrapAlignment.start,
            spacing: 6,
            runSpacing: 6,
            children: [for (final t in game.themeTags) _Pill(t.label)],
          ),
        ],
        const SizedBox(height: 22),
        SectionHeader(title: game.hasMultipleRules ? 'Règles de score' : 'Règle de score'),
        for (final (i, rule) in game.rules.indexed)
          FadeSlideIn(delay: Duration(milliseconds: 60 + i * 40), child: _RuleCard(rule: rule, showName: game.hasMultipleRules)),
        if (game.hasCharacters) ...[
          const SizedBox(height: 12),
          SectionHeader(title: '${game.characterChoice!.label} de chaque joueur'),
          _Card(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final c in game.characterChoice!.options) _Pill(c)],
            ),
          ),
        ],
        if (game.hasSetupChoice) ...[
          const SizedBox(height: 12),
          SectionHeader(title: game.setupChoice!.count == null ? game.setupChoice!.label : '${game.setupChoice!.label} · ${game.setupChoice!.count} par partie'),
          _Card(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final o in game.setupChoice!.options) _Pill(o)],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SectionHeader(title: 'Aide-mémoire', actionLabel: onEditReminders == null ? null : 'Modifier', onAction: onEditReminders),
        if (game.ruleSections.isEmpty)
          EmptyState(emoji: '📖', message: "Aucun aide-mémoire enregistré pour l'instant.")
        else
          for (final (i, section) in game.ruleSections.indexed)
            FadeSlideIn(
              delay: Duration(milliseconds: 100 + i * 40),
              child: _Card(
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
    );
  }
}

class _CompactHeader extends StatelessWidget {
  final Game game;
  final String subtitle;
  const _CompactHeader({required this.game, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16)),
          child: Text(game.emoji, style: const TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(game.name, style: dispFont(size: 19, weight: FontWeight.w800, color: AppColors.ink)),
              Text(subtitle, style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final Game game;
  final String subtitle;
  const _HeroHeader({required this.game, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 120,
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(32)),
          child: Text(game.emoji, style: const TextStyle(fontSize: 64)),
        ),
        const SizedBox(height: 16),
        Text(game.name, textAlign: TextAlign.center, style: dispFont(size: 26, weight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut)),
        if (game.defaultRule.isRanks) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(20)),
            child: Text('RÈGLES SPÉCIALES', style: bodyFont(size: 10, weight: FontWeight.w800, color: AppColors.accent, letterSpacing: 0.3)),
          ),
        ],
      ],
    );
  }
}

class _RuleCard extends StatelessWidget {
  final GameRule rule;
  final bool showName;
  const _RuleCard({required this.rule, required this.showName});

  Widget _detail(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
      );

  @override
  Widget build(BuildContext context) {
    final hasRoles = rule.isRanks && ((rule.topRoles?.isNotEmpty ?? false) || (rule.bottomRoles?.isNotEmpty ?? false));
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showName) ...[
            Text(rule.name, style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.accent)),
            const SizedBox(height: 4),
          ],
          Text(GameOverview.countDescription(rule), style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
          if (rule.pointLimit != null) _detail('Limite : ${rule.pointLimit} points'),
          if (rule.multiRound) _detail('Manches multiples activées'),
          if (rule.coop) _detail('Partie coopérative'),
          if (rule.hasScoreFields) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in rule.scoreFields!)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Color(f.color).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                    child: Text(f.label, style: bodyFont(size: 11.5, weight: FontWeight.w800, color: Color(f.color))),
                  ),
              ],
            ),
          ],
          if (hasRoles) ...[
            const SizedBox(height: 8),
            for (final r in rule.topRoles ?? const <String>[]) Text('•  $r', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2)),
            for (final r in rule.bottomRoles ?? const <String>[]) Text('•  $r', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2)),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: child,
      );
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: bodyFont(size: 11.5, weight: FontWeight.w700, color: AppColors.ink2)),
      );
}
