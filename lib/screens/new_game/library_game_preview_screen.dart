import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../services/game_rules_pdf.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/game_overview.dart';

/// Full-screen look at a library game before importing it — everything
/// [GameOverview] shows for a catalog game, plus the button that actually
/// imports it (or, when the catalog already holds a copy still following
/// it, one that just picks that copy instead of importing a duplicate).
/// Closes itself once the game is picked, back onto the new-game sheet.
class LibraryGamePreviewScreen extends StatelessWidget {
  final Game game;
  const LibraryGamePreviewScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final copy = app.libraryCopyOf(game);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        actions: [
          if (game.ruleSections.isNotEmpty)
            IconButton(icon: Icon(Icons.picture_as_pdf_rounded, color: AppColors.ink), tooltip: 'Exporter les règles en PDF', onPressed: () => exportGameRulesPdf(game)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [GameOverview(game: game, hero: true)],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.line))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (copy != null) ...[
                Text('Déjà dans votre catalogue', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut)),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Utiliser ce jeu',
                  onPressed: () {
                    app.useLibraryCopy(copy);
                    Navigator.of(context).pop();
                  },
                ),
              ] else if (app.activeContextClosed)
                Text('Ce groupe est fermé : son catalogue ne peut plus changer.', textAlign: TextAlign.center, style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut))
              else ...[
                if (app.flowError != null) ...[
                  Text(app.flowError!, style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.accent)),
                  const SizedBox(height: 8),
                ],
                PrimaryButton(
                  label: 'Ajouter à mon catalogue',
                  loading: app.busy,
                  onPressed: () async {
                    if (await app.importLibraryGame(game) && context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
