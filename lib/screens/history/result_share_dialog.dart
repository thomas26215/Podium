import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/game.dart';
import '../../models/match.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/result_share_card.dart';

const _playStoreUrl = 'https://play.google.com/store/apps/details?id=app.podium.games';

/// Previews `match`'s [ResultShareCard] and shares it as a 1080×1080 PNG
/// through the system share sheet (WhatsApp, Instagram…). Pass the whole
/// series' [legs] for a "best of N" series.
Future<void> showResultShareDialog(
  BuildContext context, {
  required Game game,
  required GameMatch match,
  required AppState appState,
  List<GameMatch>? legs,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ResultShareDialog(game: game, match: match, appState: appState, legs: legs),
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

class _ResultShareDialog extends StatefulWidget {
  final Game game;
  final GameMatch match;
  final AppState appState;
  final List<GameMatch>? legs;
  const _ResultShareDialog({required this.game, required this.match, required this.appState, this.legs});

  @override
  State<_ResultShareDialog> createState() => _ResultShareDialogState();
}

class _ResultShareDialogState extends State<_ResultShareDialog> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1080 / kShareCardSize);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png')],
        fileNameOverrides: const ['podium-resultat.png'],
        text: 'Notre partie de ${widget.game.name} sur Podium 🏆 $_playStoreUrl',
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
      constraints: const BoxConstraints(maxWidth: kShareCardSize + 32),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Partager le résultat', style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 12),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kShareCardSize),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  // Scaled down to fit a narrow dialog; the capture still
                  // happens at the card's own size (see _share).
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: ResultShareCard(game: widget.game, match: widget.match, appState: widget.appState, legs: widget.legs),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Partager', loading: _sharing, onPressed: _sharing ? null : _share),
            const SizedBox(height: 4),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
          ],
        ),
      ),
    );
  }
}
