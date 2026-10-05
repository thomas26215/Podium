import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/personal_records.dart';
import '../../logic/text_search.dart';
import '../../logic/time_format.dart';
import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/match_card.dart' show frenchDayMonth, relativeDateLabel;
import '../../widgets/option_chip.dart';
import '../../widgets/progression_chart.dart';
import '../games/game_detail_screen.dart';
import '../history/match_detail_screen.dart';
import '../new_game/new_game_sheet.dart';

/// Opens the new-match sheet straight on [game] (see
/// [AppState.startSoloMatch]) — every "Jouer"/"Rejouer" of the solo space.
Future<void> launchSoloMatch(BuildContext context, AppState app, Game game, {String? ruleId, String? setupPick}) async {
  if (app.activeContextClosed) return;
  app.startSoloMatch(game, ruleId: ruleId, setupPick: setupPick);
  await showNewGameSheet(context, app);
}

/// One game of "Mon espace solo", seen through the player's own results:
/// the record up front, how it evolved, every attempt — under one rule at
/// a time (chips on top when the game has several) and, for a game whose
/// records are split by circuit (see [Game.isSinglePickSetup]), one
/// circuit at a time — and a "Jouer" button to go again.
class SoloGameScreen extends StatefulWidget {
  final String gameId;
  final String? initialRuleId;
  final String? initialSetupPick;
  const SoloGameScreen({super.key, required this.gameId, this.initialRuleId, this.initialSetupPick});

  @override
  State<SoloGameScreen> createState() => _SoloGameScreenState();
}

class _SoloGameScreenState extends State<SoloGameScreen> {
  String? _ruleId;
  String? _pick;

  @override
  void initState() {
    super.initState();
    _ruleId = widget.initialRuleId;
    _pick = widget.initialSetupPick;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final game = app.gameById(widget.gameId);
    if (game == null) {
      return Scaffold(backgroundColor: AppColors.bg, appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0), body: const SizedBox.shrink());
    }
    final rule = game.resolveRule(_ruleId);
    final uid = app.currentUser?.uid;
    final ofRule = app.viewMatches.where((m) => m.gameId == game.id && game.resolveRule(m.ruleId).id == rule.id).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    // Circuits played, most recent first — the default is the last one.
    final playedPicks = <String>[];
    for (final m in ofRule.reversed) {
      final p = game.recordPickOf(m);
      if (p != null && !playedPicks.contains(p)) playedPicks.add(p);
    }
    final pick = game.isSinglePickSetup ? (_pick ?? playedPicks.firstOrNull) : null;
    final matches = game.isSinglePickSetup ? ofRule.where((m) => game.recordPickOf(m) == pick).toList() : ofRule;
    final allAttempts = app.soloAttempts;
    final attempts = [for (final m in matches) ?allAttempts[m.id]];
    final comparable = !rule.isRanks && !rule.isWinLoss;
    final best = attempts.where((a) => a.gapToBest == 0).lastOrNull;
    final wins = matches.where((m) => m.winnerIds().contains(uid) && (m.entries.firstOrNull?.points ?? 0) > 0).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: AppColors.ink),
            tooltip: 'Fiche du jeu',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameDetailScreen(game: game))),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                children: [
                  if (game.hasMultipleRules) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in game.rules) OptionChip(label: r.name, selected: r.id == rule.id, onTap: () => setState(() => _ruleId = r.id)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (game.isSinglePickSetup) ...[
                    _PickSelector(
                      label: game.setupChoice!.label,
                      value: pick,
                      onTap: () async {
                        final chosen = await _choosePick(context, game, playedPicks, pick);
                        if (chosen != null) setState(() => _pick = chosen);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  FadeSlideIn(
                    child: _RecordHero(
                      game: game,
                      label: comparable ? 'RECORD' : 'RÉUSSITES',
                      value: matches.isEmpty
                          ? null
                          : comparable
                              ? (best == null ? null : scoreLabel(best.value, best.unit))
                              : '$wins / ${matches.length}',
                      caption: matches.isEmpty
                          ? (pick != null ? 'Pas encore joué sur « $pick ».' : 'Pas encore joué${game.hasMultipleRules ? ' avec cette règle' : ''}.')
                          : comparable && best != null
                              ? 'Établi ${_on(best.match.createdAt)}'
                              : '${matches.length} partie${matches.length > 1 ? 's' : ''}',
                    ),
                  ),
                  if (matches.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: Row(
                        children: [
                          StatChip(value: matches.length, label: 'parties'),
                          const SizedBox(width: 10),
                          StatChip(value: comparable ? recordsBeaten(attempts) : wins, label: comparable ? 'records battus' : 'réussies'),
                        ],
                      ),
                    ),
                  ],
                  if (comparable && attempts.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    SectionHeader(title: 'Progression'),
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
                      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProgressionChart(attempts: attempts),
                          if (attempts.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 6),
                              child: Text(
                                'Chaque point est une partie, les plus gros marquent un record battu${rule.lowWins ? ' — plus bas, c’est mieux' : ''}.',
                                style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (matches.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    SectionHeader(title: 'Toutes les parties'),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
                      child: Column(
                        children: [
                          for (final m in matches.reversed)
                            Pressable(
                              behavior: HitTestBehavior.opaque,
                              dimOnPress: true,
                              pressedScale: 0.98,
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailScreen(game: game, match: m, appState: app))),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                child: Builder(builder: (_) {
                                  final a = allAttempts[m.id];
                                  final won = (m.entries.firstOrNull?.points ?? 0) > 0;
                                  return Row(
                                    children: [
                                      Expanded(child: Text(relativeDateLabel(m.createdAt), style: bodyFont(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2))),
                                      if (a != null && a.gapToBest == 0)
                                        Padding(padding: const EdgeInsets.only(right: 8), child: Text('🏆', style: bodyFont(size: 13))),
                                      if (a != null && a.wasRecord && a.gapToBest > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: Text('ancien record', style: bodyFont(size: 11, weight: FontWeight.w700, color: AppColors.mut)),
                                        ),
                                      Text(
                                        a != null ? scoreLabel(a.value, a.unit) : (won ? 'Victoire' : 'Défaite'),
                                        style: dispFont(size: 15, weight: FontWeight.w700, color: a != null && a.gapToBest == 0 ? AppColors.green : AppColors.ink),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!app.activeContextClosed)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: PrimaryButton(
                  label: matches.isEmpty ? 'Jouer' : 'Rejouer',
                  onPressed: () => launchSoloMatch(context, app, game, ruleId: rule.id, setupPick: pick),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _on(DateTime dt) {
    final label = relativeDateLabel(dt);
    return label.startsWith('Il y a') || label == "Aujourd'hui" || label == 'Hier' ? label.toLowerCase() : 'le ${frenchDayMonth(dt)}';
  }
}

/// Lists the game's circuits (see [Game.isSinglePickSetup]) — the ones
/// already played first — with a search field; returns the one tapped.
Future<String?> _choosePick(BuildContext context, Game game, List<String> played, String? current) {
  final choice = game.setupChoice!;
  var query = '';
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) {
        final q = foldText(query.trim());
        bool matches(String o) => q.isEmpty || foldText(o).contains(q);
        final others = choice.options.where((o) => !played.contains(o)).toList();
        Widget row(String o) => ListTile(
              dense: true,
              title: Text(o, style: bodyFont(size: 14.5, weight: o == current ? FontWeight.w800 : FontWeight.w600, color: AppColors.ink)),
              trailing: o == current ? Icon(Icons.check_rounded, color: AppColors.accent) : null,
              onTap: () => Navigator.of(sheetContext).pop(o),
            );
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: TextField(
                    autofocus: false,
                    onChanged: (v) => setState(() => query = v),
                    style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink),
                    decoration: appFieldDecoration(hintText: 'Rechercher', prefixIcon: Icon(Icons.search_rounded, color: AppColors.mut)),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    children: [
                      if (played.any(matches)) ...[
                        Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 4), child: Text('DÉJÀ JOUÉS', style: bodyFont(size: 11, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5))),
                        for (final o in played.where(matches)) row(o),
                      ],
                      if (others.any(matches)) ...[
                        Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 4), child: Text('TOUS', style: bodyFont(size: 11, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5))),
                        for (final o in others.where(matches)) row(o),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// "Circuit : Circuit Mario ▾" — which circuit the screen shows.
class _PickSelector extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _PickSelector({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Row(
          children: [
            Text('$label : ', style: bodyFont(size: 13.5, weight: FontWeight.w700, color: AppColors.mut)),
            Expanded(child: Text(value ?? 'Choisir', maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 14.5, weight: FontWeight.w800, color: AppColors.ink))),
            Icon(Icons.expand_more_rounded, color: AppColors.mut),
          ],
        ),
      ),
    );
  }
}

/// The dark hero card at the top: the game, a small label ("RECORD"), the
/// value in large and a caption — "Pas encore joué" before any attempt.
class _RecordHero extends StatelessWidget {
  final Game game;
  final String label;
  final String? value;
  final String caption;
  const _RecordHero({required this.game, required this.label, required this.value, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.hero, borderRadius: BorderRadius.circular(AppRadius.xxl)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.accent.withValues(alpha: 0.5), Colors.transparent])),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: bodyFont(size: 11.5, weight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 0.6)),
                    const SizedBox(height: 4),
                    Text(value ?? '—', style: dispFont(size: 34, weight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text(caption, style: bodyFont(size: 12.5, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              Text(game.emoji, style: const TextStyle(fontSize: 40)),
            ],
          ),
        ],
      ),
    );
  }
}
