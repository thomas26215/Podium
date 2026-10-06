import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../logic/plus.dart';
import '../../models/app_user.dart';
import '../../models/plus_membership.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coins.dart';
import '../../widgets/common.dart';
import '../../widgets/plus_mark.dart';
import '../plus/plus_screen.dart';
import 'coin_sheet.dart';
import 'shop_item_view.dart';

/// How the unlock sheet was left.
enum UnlockOutcome {
  /// What it was opened for is unlocked now — bought, or with Podium+.
  unlocked,

  /// The player took its other way out (see [showUnlockSheet]).
  declined,
}

/// Opens the sheet unlocking [items] — or a whole [pack] — for good with
/// jetons, topping the balance up by just what's missing; or the whole
/// catalogue at once with a membership: Podium+ for the profile card,
/// Podium++ as soon as a part of the interface is in it. Resolves to how
/// it was left — null when just closed.
///
///  * [title] and [message] head it; [preview] shows the item off.
///  * [plusPreview] or [plusPreviewLook] is what the Podium+ page shows.
///  * With [onUse], what the player has can be put on from the sheet —
///    the Boutique's way; without it, the sheet closes as soon as it's all
///    unlocked — the way of a choice waiting to be saved.
///  * [declineLabel] adds a way out without unlocking anything.
///
/// SIMULATION: no payment is taken, and the sheet says so.
Future<UnlockOutcome?> showUnlockSheet(
  BuildContext context, {
  List<ShopItem> items = const [],
  ShopPack? pack,
  required String title,
  String? message,
  Widget? preview,
  AppUser? plusPreview,
  Appearance? plusPreviewLook,
  bool plusPreviewDark = false,
  String? declineLabel,
  Future<bool> Function()? onUse,
}) {
  return showModalBottomSheet<UnlockOutcome>(
    context: context,
    sheetAnimationStyle: appSheetAnimation,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UnlockSheet(
      items: pack?.items ?? items,
      pack: pack,
      title: title,
      message: message,
      preview: preview,
      plusPreview: plusPreview,
      plusPreviewLook: plusPreviewLook,
      plusPreviewDark: plusPreviewDark,
      declineLabel: declineLabel,
      onUse: onUse,
    ),
  );
}

class _UnlockSheet extends StatefulWidget {
  final List<ShopItem> items;
  final ShopPack? pack;
  final String title;
  final String? message;
  final Widget? preview;
  final AppUser? plusPreview;
  final Appearance? plusPreviewLook;
  final bool plusPreviewDark;
  final String? declineLabel;
  final Future<bool> Function()? onUse;
  const _UnlockSheet({
    required this.items,
    required this.pack,
    required this.title,
    required this.message,
    required this.preview,
    required this.plusPreview,
    required this.plusPreviewLook,
    required this.plusPreviewDark,
    required this.declineLabel,
    required this.onUse,
  });

  @override
  State<_UnlockSheet> createState() => _UnlockSheetState();
}

class _UnlockSheetState extends State<_UnlockSheet> {
  bool _busy = false;

  void _close(UnlockOutcome? outcome) => Navigator.of(context).pop(outcome);

  Future<void> _buy(AppState app, List<ShopItem> toBuy, int price) async {
    setState(() => _busy = true);
    final ok = await app.buyWithCoins(toBuy, price: price);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    HapticFeedback.mediumImpact();
    // Bought for a choice waiting to be saved: back to it. In the
    // Boutique, the sheet stays, to put it on.
    if (widget.onUse == null) _close(UnlockOutcome.unlocked);
  }

  /// Buys exactly the [missing] jetons — never more than needed.
  Future<void> _topUp(AppState app, int missing) async {
    setState(() => _busy = true);
    // SIMULATION: the store's payment sheet will open here.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await app.simulateBuyCoins(CoinPack.exactly(missing));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _use() async {
    setState(() => _busy = true);
    final ok = await widget.onUse!();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _close(UnlockOutcome.unlocked);
  }

  Future<void> _joinPlus(PlusTier tier) async {
    final outcome = await PlusScreen.open(context, minTier: tier, preview: widget.plusPreview, previewLook: widget.plusPreviewLook, previewDark: widget.plusPreviewDark);
    if (outcome == PlusOutcome.joined && mounted && widget.onUse == null) _close(UnlockOutcome.unlocked);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final me = app.currentUser;
    if (me == null) return const SizedBox.shrink();
    final unlocks = app.unlocks;
    final all = widget.items;
    final toBuy = [for (final i in all) if (!unlocks.owns(i)) i];
    final price = widget.pack?.priceFor(unlocks.owned) ?? toBuy.fold<int>(0, (sum, i) => sum + i.price);
    // Crossed out: the missing items one by one, when the pack is cheaper.
    final fullPrice = widget.pack?.restFor(unlocks.owned);
    final covered = all.every(unlocks.has);
    final missing = price - app.coins;
    // The membership that would cover it all — offered unless theirs does.
    final needed = tierFor(all);
    final offerTier = unlocks.tier == null || (needed == PlusTier.plusPlus && unlocks.tier == PlusTier.plus) ? needed : null;
    final showRows = widget.preview == null || all.length > 1;

    const simulation = Padding(
      padding: EdgeInsets.only(top: 6),
      child: _SimulationNote(),
    );

    final List<Widget> action;
    if (covered) {
      final ownsAll = toBuy.isEmpty;
      action = [
        Row(
          children: [
            if (ownsAll) Icon(Icons.check_circle_rounded, size: 18, color: AppColors.green) else PlusMark(size: 18, rim: false, tier: unlocks.tier!),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ownsAll ? 'À vous pour toujours.' : 'Inclus dans votre ${unlocks.tier!.label}.',
                style: bodyFont(size: 14, weight: FontWeight.w800, color: ownsAll ? AppColors.green : AppColors.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryButton(label: widget.onUse != null ? 'Utiliser' : 'Continuer', loading: _busy, onPressed: widget.onUse != null ? _use : () => _close(UnlockOutcome.unlocked)),
        // A member may still buy it, to keep it without Podium+.
        if (!ownsAll && price > 0) ...[
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => missing > 0 ? _topUp(app, missing) : _buy(app, toBuy, price),
              child: Text(
                missing > 0 ? 'Le garder pour toujours : obtenir ${coinsLabel(missing)} (${euros(coinsToCents(missing))})' : 'L’acheter pour le garder pour toujours · ${coinsLabel(price)}',
                textAlign: TextAlign.center,
                style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.accent),
              ),
            ),
          ),
          simulation,
        ],
      ];
    } else {
      action = [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    switch (widget.pack) {
                      final pack? when pack.isTheme => 'Prix du thème',
                      _? => 'Prix du pack',
                      null => 'Prix',
                    },
                    style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink2),
                  ),
                  // A theme costs its parts: say so, as it's not a pack deal.
                  if (widget.pack?.isTheme ?? false)
                    Text(
                      all.any(unlocks.owns) ? 'Ses éléments, sans ceux que vous avez' : 'La somme de ses éléments',
                      style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (fullPrice != null && fullPrice > price) ...[
              Text(groupDigits(fullPrice), style: dispFont(size: 14, weight: FontWeight.w600, color: AppColors.mut).copyWith(decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 8),
            ],
            CoinAmount(price, size: 18),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text('soit ${euros(coinsToCents(price))}', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('Votre solde', style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink2)),
            const SizedBox(width: 10),
            CoinAmount(app.coins, size: 14, color: AppColors.ink2),
            const Spacer(),
            Pressable(
              onTap: _busy ? null : () => showCoinSheet(context),
              child: Text('Recharger', style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.accent)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: missing > 0 ? 'Obtenir les ${coinsLabel(missing)} manquants · ${euros(coinsToCents(missing))}' : 'Acheter pour ${coinsLabel(price)}',
          loading: _busy,
          onPressed: missing > 0 ? () => _topUp(app, missing) : () => _buy(app, toBuy, price),
        ),
        simulation,
        if (offerTier != null) ...[
          const SizedBox(height: 12),
          _PlusOffer(tier: offerTier, upgrade: unlocks.tier != null, onTap: _busy ? null : () => _joinPlus(offerTier)),
        ],
        if (widget.declineLabel != null)
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => _close(UnlockOutcome.declined),
              child: Text(widget.declineLabel!, style: bodyFont(size: 13.5, weight: FontWeight.w700, color: AppColors.mut)),
            ),
          ),
      ];
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: bodyFont(size: 18, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2)),
                        if (widget.message != null) ...[
                          const SizedBox(height: 3),
                          Text(widget.message!, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut, height: 1.35)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(tooltip: 'Fermer', icon: Icon(Icons.close_rounded, color: AppColors.ink), onPressed: () => _close(null)),
                ],
              ),
              if (widget.preview != null) ...[
                const SizedBox(height: 14),
                widget.preview!,
              ],
              if (showRows) ...[
                const SizedBox(height: 10),
                for (final item in all) _ItemRow(item: item, user: me, owned: unlocks.owns(item), app: app),
              ],
              const SizedBox(height: 16),
              ...action,
            ],
          ),
        ),
      ),
    );
  }
}

/// Says, under the button, that nothing is really paid yet.
class _SimulationNote extends StatelessWidget {
  const _SimulationNote();

  @override
  Widget build(BuildContext context) {
    return Text('Simulation : aucun paiement n’est effectué.', textAlign: TextAlign.center, style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.gold));
  }
}

/// One item in the sheet: its picture, name, kind, and price — or a tick
/// once it's owned.
class _ItemRow extends StatelessWidget {
  final ShopItem item;
  final AppUser user;
  final bool owned;
  final AppState app;
  const _ItemRow({required this.item, required this.user, required this.owned, required this.app});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.scaled(10)),
            child: SizedBox(width: 64, height: 44, child: ShopItemThumb(item: item, user: user, base: app.appearance, dark: app.isDark)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shopItemLabel(item), maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
                Text(item.kind.label, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (owned) Icon(Icons.check_circle_rounded, size: 20, color: AppColors.green) else CoinAmount(item.price, size: 13, color: AppColors.ink2),
        ],
      ),
    );
  }
}

/// The other way: everything at once, with a membership — or, for a
/// Podium+ member, by moving up to Podium++.
class _PlusOffer extends StatelessWidget {
  final PlusTier tier;
  final bool upgrade;
  final VoidCallback? onTap;
  const _PlusOffer({required this.tier, required this.upgrade, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(1.4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg + 1.4), gradient: const LinearGradient(colors: kPlusGradient)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), color: kPlusNight),
          child: Row(
            children: [
              PlusMark(size: 24, rim: false, tier: tier),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(upgrade ? 'Ou passer à ${tier.label}' : 'Ou tout débloquer avec ${tier.label}', style: bodyFont(size: 14, weight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(
                      switch ((tier, upgrade)) {
                        (PlusTier.plus, _) => 'Toute la carte de profil · dès 1,67 € par mois',
                        (PlusTier.plusPlus, false) => 'La carte et toute l’interface · dès 2,50 € par mois',
                        (PlusTier.plusPlus, true) => 'Toute l’interface en plus de votre carte',
                      },
                      style: bodyFont(size: 12, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}
