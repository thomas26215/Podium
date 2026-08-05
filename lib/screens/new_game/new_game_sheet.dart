import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'game_library_browser.dart';
import 'other_groups_game_browser.dart';
import 'step1_game.dart';
import 'step2_players.dart';
import 'step3_scores.dart';

/// Presents the new-game/scoring sheet and cleans up after it closes,
/// regardless of how it closed (saved, backed out, or cancelled — see
/// `AppState.closeSheet`). Callers are responsible for preparing `AppState`
/// beforehand: `app.openSheet()` for a brand-new match, or
/// `app.resumeLocalDraft()` to continue one found on this device.
Future<void> showNewGameSheet(BuildContext context, AppState app) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x6B141318),
    // Scores are often entered live over the course of a whole game — an
    // accidental swipe-down or stray tap outside shouldn't discard that
    // progress. Leaving is still one tap away via the header's close/back
    // button.
    enableDrag: false,
    isDismissible: false,
    builder: (_) => ChangeNotifierProvider.value(value: app, child: const NewGameSheet()),
  );
  app.closeSheet();
}

/// After saving a non-final leg of a "best of N" series, checks whether the
/// series is already mathematically decided (see
/// `AppState.draftSeriesDecided`) and, if so and not opted out for this
/// series, asks whether to keep playing the remaining legs or stop here.
Future<void> _maybeShowSeriesDecidedPrompt(BuildContext context, AppState app) async {
  if (app.draft.bestOf <= 1 || app.draft.seriesDecidedPromptDismissed || !app.draftSeriesDecided) return;
  var dontShowAgain = false;
  final leader = app.draftSeriesLeaderLabel;
  final action = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Série déjà jouée ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$leader ne peut plus être rattrapé(e) : la série est déjà gagnée. Voulez-vous continuer à jouer les parties restantes ?',
              style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => dontShowAgain = !dontShowAgain),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Checkbox(
                      value: dontShowAgain,
                      activeColor: AppColors.accent,
                      onChanged: (v) => setState(() => dontShowAgain = v ?? false),
                    ),
                    Expanded(child: Text('Ne plus afficher pour cette partie', style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.ink2))),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop('stop'), child: Text('Arrêter la série', style: TextStyle(color: AppColors.accent))),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop('continue'), child: const Text('Continuer à jouer')),
        ],
      ),
    ),
  );
  if (dontShowAgain) app.dismissSeriesDecidedPrompt();
  if (action == 'stop') {
    await app.endSeriesEarly();
    if (!app.sheetOpen && context.mounted) Navigator.of(context).pop();
  }
}

class NewGameSheet extends StatelessWidget {
  const NewGameSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final titles = {1: 'Quel jeu ?', 2: 'Qui joue ?', 3: 'Les scores'};
    // "Manche" is already used for a round within a single match (Président
    // hands, points-per-round…) — a best-of-N leg is a whole separate match,
    // so it's labelled "Partie" to avoid clashing with that vocabulary.
    final seriesPrefix = app.draft.bestOf > 1 ? 'Partie ${app.draft.seriesLegIndex}/${app.draft.bestOf} — ' : '';
    final subs = {
      1: 'Choisissez la partie',
      2: app.draft.mode == 'team' ? 'Répartissez les équipes' : 'Sélectionnez les joueurs',
      3: '$seriesPrefix${app.draft.unit == 'wins' ? 'Manches gagnées par chacun' : 'Entrez les points de chacun'}',
    };
    final title = app.browsingLibrary
        ? 'Bibliothèque de jeux'
        : (app.browsingOtherGroups
            ? 'Vos autres groupes'
            : (app.creatingGame ? (app.isEditingGame ? 'Modifier le jeu' : 'Nouveau jeu') : titles[app.step]!));
    final subtitle = app.browsingLibrary
        ? 'Importez un jeu prêt à l\'emploi'
        : (app.browsingOtherGroups
            ? 'Réutilisez un jeu existant'
            : (app.creatingGame ? (app.isEditingGame ? 'Ajustez ses paramètres' : 'Ajoutez-le à votre catalogue') : subs[app.step]!));
    final showBack = app.browsingLibrary || app.browsingOtherGroups || app.creatingGame || app.step > 1;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        if (!showBack) {
                          Navigator.of(context).pop();
                        } else {
                          app.sheetBack();
                        }
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
                        child: Icon(showBack ? Icons.arrow_back : Icons.close, size: 18, color: AppColors.ink),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: bodyFont(size: 18, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2)),
                          Text(subtitle, style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.mut)),
                        ],
                      ),
                    ),
                    if (!app.creatingGame && !app.browsingLibrary && !app.browsingOtherGroups)
                      Row(
                        children: [
                          for (var i = 1; i <= 3; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.only(left: 5),
                              width: app.step >= i ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: app.step >= i ? AppColors.accent : AppColors.line,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              if (app.step == 3 && !app.creatingGame && !app.isOnline)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 15, color: AppColors.mut),
                      const SizedBox(width: 6),
                      Text("Hors ligne — la partie n'est pas visible en direct", style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.mut)),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(animation),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(
                        app.browsingLibrary ? 'lib' : app.browsingOtherGroups ? 'other' : app.creatingGame ? 'create' : 'step${app.step}',
                      ),
                      child: app.browsingLibrary
                          ? const GameLibraryBrowser()
                          : app.browsingOtherGroups
                              ? const OtherGroupsGameBrowser()
                              : app.creatingGame
                                  ? const CreateGameForm()
                                  : switch (app.step) {
                                      1 => const Step1Game(),
                                      2 => const Step2Players(),
                                      _ => const Step3Scores(),
                                    },
                    ),
                  ),
                ),
              ),
              if (!app.browsingLibrary && !app.browsingOtherGroups)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line)), color: AppColors.bg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (app.flowError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
                        ),
                      PrimaryButton(
                        label: app.creatingGame
                            ? (app.isEditingGame ? 'Enregistrer les modifications' : 'Créer le jeu')
                            : (app.step != 3
                                ? 'Continuer'
                                : (app.draft.bestOf <= 1
                                    ? 'Enregistrer la partie'
                                    : (app.draft.seriesLegIndex >= app.draft.bestOf
                                        ? 'Enregistrer la dernière partie'
                                        : 'Enregistrer la partie ${app.draft.seriesLegIndex}/${app.draft.bestOf}'))),
                        loading: app.busy || app.savingMatch,
                        onPressed: app.canProceed
                            ? () async {
                                await app.primaryAction();
                                if (!context.mounted) return;
                                if (!app.sheetOpen) {
                                  Navigator.of(context).pop();
                                } else {
                                  await _maybeShowSeriesDecidedPrompt(context, app);
                                }
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
