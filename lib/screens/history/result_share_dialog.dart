import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/game.dart';
import '../../models/match.dart';
import '../../models/tournament.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/result_share_card.dart';
import '../../widgets/tournament_share_card.dart';

const _playStoreUrl = 'https://play.google.com/store/apps/details?id=app.podium.games';

/// Previews `match`'s [ResultShareCard] and shares it as an image through
/// the system share sheet (WhatsApp, Instagram…). Pass the whole series'
/// [legs] for a "best of N" series.
Future<void> showResultShareDialog(
  BuildContext context, {
  required Game game,
  required GameMatch match,
  required AppState appState,
  List<GameMatch>? legs,
}) {
  return _showShareImageDialog(
    context,
    card: ResultShareCard(game: game, match: match, appState: appState, legs: legs),
    text: 'Notre partie de ${game.name} sur Podium 🏆 $_playStoreUrl',
  );
}

/// Same as [showResultShareDialog], for a whole tournament (see
/// [TournamentShareCard]).
Future<void> showTournamentShareDialog(
  BuildContext context, {
  required Tournament tournament,
  required Game? game,
  required AppState appState,
}) {
  return _showShareImageDialog(
    context,
    card: TournamentShareCard(tournament: tournament, game: game, appState: appState),
    text: 'Notre tournoi « ${tournament.name} » sur Podium 🏆 $_playStoreUrl',
  );
}

/// The legs of `match`'s "best of N" series, in order — or null when it
/// isn't part of one.
List<GameMatch>? seriesLegsOf(GameMatch match, AppState appState) {
  final sid = match.seriesId;
  if (sid == null) return null;
  final legs = appState.matches.where((m) => m.seriesId == sid).toList()..sort((a, b) => (a.seriesGame ?? 0).compareTo(b.seriesGame ?? 0));
  return legs.isEmpty ? null : legs;
}

Future<void> _showShareImageDialog(BuildContext context, {required Widget card, required String text}) {
  return showAppDialog<void>(context: context, builder: (_) => _ShareImageDialog(card: card, text: text));
}

/// Previews [card] (a [kShareCardWidth]-wide share card, as tall as its
/// content) and shares it as a PNG, [kShareImageWidth] pixels wide.
class _ShareImageDialog extends StatefulWidget {
  final Widget card;
  final String text;
  const _ShareImageDialog({required this.card, required this.text});

  @override
  State<_ShareImageDialog> createState() => _ShareImageDialogState();
}

class _ShareImageDialogState extends State<_ShareImageDialog> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: kShareImageWidth / kShareCardWidth);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png')],
        fileNameOverrides: const ['podium-resultat.png'],
        text: widget.text,
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible de partager l'image.")));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg,
      constraints: const BoxConstraints(maxWidth: kShareCardWidth + 32),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text('Partager le résultat', style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
          ),
          // A tall card (tournament bracket, score chart…) scrolls inside
          // the dialog; the buttons below always stay visible.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kShareCardWidth),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    // Scaled down to fit a narrow dialog; the capture still
                    // happens at the card's own size (see _share).
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RepaintBoundary(key: _cardKey, child: widget.card),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: PrimaryButton(label: 'Partager', loading: _sharing, onPressed: _sharing ? null : _share),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
          ),
        ],
      ),
    );
  }
}
