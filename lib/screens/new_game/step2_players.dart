import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/match_card.dart' show relativeDateLabel;

class Step2Players extends StatelessWidget {
  const Step2Players({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final d = app.draft;
    final players = app.viewPlayers;
    final rule = app.draftRule;
    // Ranks and win/loss rules are always solo scoring, and a rule flagged
    // GameRule.coop picks the mode by itself — none of these ever show the
    // "Chacun pour soi"/"Équipes" choice (see AppState._applyRule, which
    // sets draft.mode accordingly up front). Every other rule keeps that
    // choice exactly as before.
    final modeFixed = rule != null && (rule.isRanks || rule.isWinLoss || rule.coop);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayBefore = today.subtract(const Duration(days: 2));
    final chosen = app.effectivePlayedAt;
    final isCustom = chosen != today && chosen != yesterday && chosen != dayBefore;

    // A tournament's entrants are a fixed roster for the whole bracket, not
    // one dated event with a best-of-N format — those two sections only
    // make sense when this step is picking players for a single match (see
    // AppState.isTournamentFlow).
    final isTournamentFlow = app.isTournamentFlow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isTournamentFlow) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quand ?', style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.ink2)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DateChip(label: "Aujourd'hui", selected: chosen == today, onTap: () => app.setPlayedAt(null)),
                    _DateChip(label: 'Hier', selected: chosen == yesterday, onTap: () => app.setPlayedAt(yesterday)),
                    _DateChip(label: 'Avant-hier', selected: chosen == dayBefore, onTap: () => app.setPlayedAt(dayBefore)),
                    _DateChip(
                      icon: Icons.calendar_month_rounded,
                      label: isCustom ? relativeDateLabel(chosen) : null,
                      selected: isCustom,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: chosen,
                          firstDate: today.subtract(const Duration(days: 365 * 3)),
                          lastDate: today,
                          helpText: 'Quand a eu lieu la partie ?',
                          cancelText: 'Annuler',
                          confirmText: 'Choisir',
                        );
                        if (picked != null) app.setPlayedAt(picked);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Format de la partie', style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.ink2)),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(11)),
                  child: Row(
                    children: [
                      for (final n in [1, 3, 5, 7])
                        Pressable(
                          onTap: () => app.setBestOf(n),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 40,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: d.bestOf == n ? AppColors.ink : null, borderRadius: BorderRadius.circular(8)),
                            child: Text(n == 1 ? 'x1' : 'Bo$n', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: d.bestOf == n ? Colors.white : AppColors.mut)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (isTournamentFlow)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Sélectionnez les participants dans l\'ordre : en cas de nombre impair, les premiers de la liste ont plus de chances d\'avoir un tour de repos au premier tour.',
              style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
            ),
          ),
        if (!modeFixed) ...[
          Row(
            children: [
              Expanded(child: _ModeCard(label: 'Chacun pour soi', sub: 'Score individuel', selected: d.mode == 'ffa', onTap: () => app.setMode('ffa'))),
              const SizedBox(width: 10),
              Expanded(child: _ModeCard(label: 'Équipes', sub: '2 à 4 camps', selected: d.mode == 'team', onTap: () => app.setMode('team'))),
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (d.mode == 'coop')
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.accentSoft, border: Border.all(color: AppColors.accent.withValues(alpha: 0.35), width: 1.2), borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Row(
                children: [
                  Icon(Icons.diversity_3_rounded, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Partie coopérative : tout le groupe gagne ou perd ensemble contre le jeu.', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink)),
                  ),
                ],
              ),
            ),
          ),
        if (d.mode == 'team')
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Nombre d'équipes", style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.ink2)),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(11)),
                  child: Row(
                    children: [
                      for (final n in [2, 3, 4])
                        Pressable(
                          onTap: () => app.setTeamCount(n),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 34,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: d.teamCount == n ? AppColors.ink : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$n', style: bodyFont(size: 13, weight: FontWeight.w800, color: d.teamCount == n ? Colors.white : AppColors.mut)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        for (final (i, p) in players.indexed)
          FadeSlideIn(
            delay: Duration(milliseconds: i * 30),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: d.playerIds.contains(p.uid) ? AppColors.accent : AppColors.line, width: 1.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Pressable(onTap: () => app.togglePlayer(p.uid), child: Avatar(initial: p.initial, color: Color(p.color), size: 38, fontSize: 15)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Pressable(
                      onTap: () => app.togglePlayer(p.uid),
                      child: Text(p.displayName, style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                    ),
                  ),
                  if (d.playerIds.contains(p.uid) && d.mode == 'team')
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(11)),
                      child: Row(
                        children: [
                          for (var i = 0; i < d.teamCount; i++)
                            Builder(builder: (_) {
                              final label = String.fromCharCode(65 + i);
                              final on = (d.team[p.uid] ?? 'A') == label;
                              return Pressable(
                                onTap: () => app.setPlayerTeam(p.uid, label),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 34,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: on ? AppColors.ink : null, borderRadius: BorderRadius.circular(8)),
                                  child: Text(label, style: bodyFont(size: 13, weight: FontWeight.w800, color: on ? Colors.white : AppColors.mut)),
                                ),
                              );
                            }),
                        ],
                      ),
                    )
                  else if (!(d.mode == 'team' && d.playerIds.contains(p.uid)))
                    Pressable(
                      onTap: () => app.togglePlayer(p.uid),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: d.playerIds.contains(p.uid) ? AppColors.accent : null,
                          border: Border.all(color: d.playerIds.contains(p.uid) ? AppColors.accent : AppColors.line, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: d.playerIds.contains(p.uid) ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
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

class _DateChip extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _DateChip({this.label, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.mut;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.card,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 14, color: color),
            if (icon != null && label != null) const SizedBox(width: 6),
            if (label != null) Text(label!, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _ModeCard({required this.label, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.card,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            Text(label, style: bodyFont(size: 14, weight: FontWeight.w800, color: selected ? Colors.white : AppColors.ink)),
            Text(sub, style: bodyFont(size: 11, weight: FontWeight.w600, color: selected ? Colors.white.withValues(alpha: 0.7) : AppColors.mut)),
          ],
        ),
      ),
    );
  }
}
