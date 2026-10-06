import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../logic/plus.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coins.dart';
import '../../widgets/common.dart';

/// Opens the jeton packs; resolves to how many jetons were bought — null
/// when closed without buying.
///
/// SIMULATION: buying takes no payment (see AppState.simulateBuyCoins),
/// and the sheet says so.
Future<int?> showCoinSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    sheetAnimationStyle: appSheetAnimation,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CoinSheet(),
  );
}

class _CoinSheet extends StatefulWidget {
  const _CoinSheet();

  @override
  State<_CoinSheet> createState() => _CoinSheetState();
}

class _CoinSheetState extends State<_CoinSheet> {
  /// The pack being bought, while its payment goes through.
  CoinPack? _buying;

  Future<void> _buy(AppState app, CoinPack pack) async {
    setState(() => _buying = pack);
    // SIMULATION: the store's payment sheet will open here.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final ok = await app.simulateBuyCoins(pack);
    if (!mounted) return;
    setState(() => _buying = null);
    if (!ok) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(pack.total);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Jetons', style: bodyFont(size: 18, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2))),
                  IconButton(tooltip: 'Fermer', icon: Icon(Icons.close_rounded, color: AppColors.ink), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              Row(
                children: [
                  Text('Votre solde', style: bodyFont(size: 13.5, weight: FontWeight.w700, color: AppColors.mut)),
                  const SizedBox(width: 10),
                  CoinAmount(app.coins, size: 16),
                ],
              ),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.86,
                children: [
                  for (final (i, pack) in kCoinPacks.indexed)
                    FadeSlideIn(
                      delay: staggerDelay(i, stepMs: 45),
                      child: _PackTile(pack: pack, size: i, buying: _buying == pack, onTap: _buying == null ? () => _buy(app, pack) : null),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '100 jetons = 1 €. Les jetons n’expirent pas et ne servent que dans Podium, pour débloquer des objets de la Boutique.',
                style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut, height: 1.35),
              ),
              const SizedBox(height: 6),
              Text('Simulation : aucun paiement n’est effectué.', style: bodyFont(size: 12, weight: FontWeight.w800, color: AppColors.gold)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One pack: a pile of coins growing with it, how many, the bonus, the
/// price.
class _PackTile extends StatelessWidget {
  final CoinPack pack;

  /// Its rank among the packs — how high the pile is.
  final int size;
  final bool buying;
  final VoidCallback? onTap;
  const _PackTile({required this.pack, required this.size, required this.buying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tag = pack.tag;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: cardDecoration(radius: AppRadius.lg, border: tag != null ? AppColors.gold : null, borderWidth: tag != null ? 1.5 : 1),
        child: Column(
          children: [
            Row(
              children: [
                const Spacer(),
                if (tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(6)),
                    child: Text(tag, style: bodyFont(size: 10, weight: FontWeight.w800, color: Colors.white)),
                  ),
              ],
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 64,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // The pile: one coin more for each bigger pack.
                      for (var k = 0; k <= size; k++)
                        Positioned(
                          bottom: k * 5.0,
                          left: 32 - 15 + (k.isOdd ? 3.0 : -3.0) * (k == 0 ? 0 : 1),
                          child: const CoinIcon(size: 30),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Text(groupDigits(pack.total), style: dispFont(size: 22, weight: FontWeight.w700, color: AppColors.ink)),
            Text(pack.bonus > 0 ? 'dont ${groupDigits(pack.bonus)} offerts' : 'jetons', style: bodyFont(size: 11.5, weight: FontWeight.w700, color: pack.bonus > 0 ? AppColors.green : AppColors.mut)),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: accentDecoration(radius: AppRadius.md, glow: false, enabled: onTap != null || buying),
              child: buying
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(euros(pack.cents), style: bodyFont(size: 14, weight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
