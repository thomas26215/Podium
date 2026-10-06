import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../logic/plus.dart';
import '../../models/app_user.dart';
import '../../models/plus_membership.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ambient_loop.dart';
import '../../widgets/appearance_preview.dart';
import '../../widgets/common.dart';
import '../../widgets/fx_kit.dart';
import '../../widgets/match_card.dart' show frenchDayMonth;
import '../../widgets/plus_mark.dart';
import '../../widgets/profile_banners.dart';
import '../../widgets/profile_style.dart';
import '../profile/profile_header.dart';

/// How the Podium+ page was left.
enum PlusOutcome {
  /// The player has the membership they needed now — they just joined.
  joined,

  /// They took the page's other way out (see [PlusScreen.declineLabel]).
  declined,
}

typedef _Offer = ({String title, String price, String per, String? detail, String? tag, String cta, String fine});

/// What each plan of each tier shows — placeholders until real purchases
/// bring the store's own prices, in the player's currency. A member moving
/// up ([upgrade]) gets no second free week.
_Offer _offer(PlusTier tier, PlusPlan plan, {bool upgrade = false}) {
  final plus = tier == PlusTier.plus;
  final verb = upgrade ? 'Passer à ${tier.label}' : 'S’abonner';
  return switch (plan) {
    PlusPlan.yearly => (
        title: 'Annuel',
        price: plus ? '19,99 €' : '29,99 €',
        per: 'par an',
        detail: upgrade ? 'Soit ${plus ? '1,67' : '2,50'} € par mois' : '7 jours offerts, puis ${plus ? '1,67' : '2,50'} € par mois',
        tag: '−44 %',
        cta: upgrade ? '$verb pour ${plus ? '19,99' : '29,99'} € par an' : 'Essayer 7 jours gratuitement',
        fine: upgrade ? 'Remplace votre abonnement actuel, tout de suite. Annulable à tout moment.' : 'Puis ${plus ? '19,99' : '29,99'} € par an. Annulable à tout moment.',
      ),
    PlusPlan.monthly => (
        title: 'Mensuel',
        price: plus ? '2,99 €' : '4,49 €',
        per: 'par mois',
        detail: 'Sans engagement',
        tag: null,
        cta: '$verb pour ${plus ? '2,99' : '4,49'} € par mois',
        fine: upgrade ? 'Remplace votre abonnement actuel, tout de suite. Sans engagement.' : 'Sans engagement, annulable à tout moment.',
      ),
    PlusPlan.lifetime => (
        title: 'Fondateur à vie',
        price: '49,99 €',
        per: 'une seule fois',
        detail: 'Podium++ pour toujours, et le badge exclusif Fondateur',
        tag: 'Offre de lancement',
        cta: 'Devenir Fondateur pour 49,99 €',
        fine: 'Un seul paiement : Podium++ reste à vous pour toujours.',
      ),
  };
}

/// The plans of [tier] — the lifetime one is Podium++'s, while its launch
/// offer runs.
List<PlusPlan> _plansOf(PlusTier tier) => [PlusPlan.yearly, PlusPlan.monthly, if (tier == PlusTier.plusPlus && founderOfferOpen(DateTime.now())) PlusPlan.lifetime];

/// "6 oct. 2026".
String _longDate(DateTime d) => '${frenchDayMonth(d)} ${d.year}';

/// The Podium+ page: what Podium+ (the profile card) and Podium++ (the card
/// and the whole interface) unlock, and the plans to get them — or, for a
/// member, their membership, and a way up to Podium++. Always on its own
/// night sky, whatever the app's look.
///
/// SIMULATION: "buying" takes no payment (see
/// AppState.simulatePlusPurchase), and the page says so.
class PlusScreen extends StatefulWidget {
  /// The tier the caller needs: Podium++ for a part of the interface — the
  /// page then offers it alone, as the way up for a Podium+ member too.
  final PlusTier minTier;

  /// A card to show off at the top — the profile editor's draft, so the
  /// player sees their own picks with Podium+. Without it (nor
  /// [previewLook]), their own card, dressed up.
  final AppUser? preview;

  /// An app look to show off instead — a theme or style picked in the
  /// settings — in dark mode when [previewDark].
  final Appearance? previewLook;
  final bool previewDark;

  /// A second way out under the main button, e.g. "Enregistrer sans ces
  /// options" — it pops with [PlusOutcome.declined].
  final String? declineLabel;

  const PlusScreen({super.key, this.minTier = PlusTier.plus, this.preview, this.previewLook, this.previewDark = false, this.declineLabel});

  /// Pushes the page; resolves to how it was left — null when just closed.
  static Future<PlusOutcome?> open(BuildContext context, {PlusTier minTier = PlusTier.plus, AppUser? preview, Appearance? previewLook, bool previewDark = false, String? declineLabel}) {
    return Navigator.of(context).push<PlusOutcome>(
      MaterialPageRoute(builder: (_) => PlusScreen(minTier: minTier, preview: preview, previewLook: previewLook, previewDark: previewDark, declineLabel: declineLabel)),
    );
  }

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  late PlusTier _tier = widget.minTier;
  PlusPlan _plan = PlusPlan.yearly;
  bool _buying = false;

  /// A Podium+ member who asked to move up to Podium++ on the page.
  bool _upgrading = false;

  /// What the player joined on this page, which turns into a welcome.
  ({PlusTier tier, PlusPlan plan})? _joined;

  void _pickTier(PlusTier tier) => setState(() {
        _tier = tier;
        if (!_plansOf(tier).contains(_plan)) _plan = PlusPlan.yearly;
      });

  Future<void> _buy(AppState app) async {
    setState(() => _buying = true);
    // SIMULATION: the store's payment sheet will open here.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final tier = _plan == PlusPlan.lifetime ? PlusTier.plusPlus : _tier;
    final ok = await app.simulatePlusPurchase(tier, _plan);
    if (!mounted) return;
    setState(() {
      _buying = false;
      if (ok) _joined = (tier: tier, plan: _plan);
    });
    if (ok) HapticFeedback.heavyImpact();
  }

  Future<void> _cancel(AppState app, PlusMembership membership) async {
    final lifetime = membership.plan == PlusPlan.lifetime;
    final name = membership.tier.label;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text(lifetime ? 'Retirer $name ?' : 'Résilier $name ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
        content: Text(
          'Simulation : $name s’arrête tout de suite. Vos choix restent enregistrés et reviendront si vous le reprenez — ce que vous avez acheté dans la Boutique reste à vous.',
          style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(lifetime ? 'Retirer' : 'Résilier', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await app.simulatePlusCancel();
    if (!ok || !mounted) return;
    app.showToast(lifetime ? '$name retiré.' : 'Abonnement $name résilié.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final me = app.currentUser;
    final membership = me?.plus;
    // A Podium+ member moves up to Podium++ here when the caller needs it,
    // or when they ask to on their membership card.
    final upgrading = _joined == null && membership?.tier == PlusTier.plus && (widget.minTier == PlusTier.plusPlus || _upgrading);
    final buying = _joined == null && (membership == null || upgrading);
    final managing = _joined == null && !buying;
    final tier = buying ? (upgrading ? PlusTier.plusPlus : _tier) : (_joined?.tier ?? membership?.tier ?? _tier);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kPlusNight,
        body: Stack(
          children: [
            const Positioned.fill(child: _NightSky()),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 2, 16, 0),
                    child: Row(
                      children: [
                        IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
                        const Spacer(),
                        const _SimulationTag(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        _hero(tier, membership, upgrading: upgrading),
                        const SizedBox(height: 22),
                        FadeSlideIn(delay: const Duration(milliseconds: 80), child: _preview(me, tier)),
                        if (managing && membership != null) ...[
                          const SizedBox(height: 24),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 120),
                            child: _MembershipCard(
                              membership: membership,
                              onCancel: () => _cancel(app, membership),
                              onUpgrade: membership.tier == PlusTier.plus ? () => setState(() => _upgrading = true) : null,
                            ),
                          ),
                        ],
                        const SizedBox(height: 26),
                        _SectionTitle(buying ? 'Avec Podium+ — votre carte' : (tier == PlusTier.plus ? 'Débloqué pour vous' : 'Votre carte')),
                        _Perks(perks: _Perks.card(tier)),
                        const SizedBox(height: 16),
                        // What Podium++ adds — dimmed while Podium+ is the one on show.
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: tier == PlusTier.plusPlus ? 1 : 0.5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionTitle(tier == PlusTier.plusPlus && !buying ? 'Et toute l’interface' : 'En plus avec Podium++ — l’interface'),
                              _Perks(perks: _Perks.interface()),
                            ],
                          ),
                        ),
                        if (buying) ...[
                          const SizedBox(height: 26),
                          // Both tiers on offer: picked right above their plans,
                          // by the button.
                          if (!upgrading && widget.minTier == PlusTier.plus) ...[
                            const _SectionTitle('Choisissez votre formule'),
                            _TierSwitch(selected: _tier, onPick: _buying ? null : _pickTier),
                            const SizedBox(height: 12),
                          ] else
                            _SectionTitle('Choisissez votre formule ${tier.label}'),
                          for (final p in _plansOf(tier))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PlanTile(offer: _offer(tier, p, upgrade: upgrading), selected: _plan == p, onTap: _buying ? null : () => setState(() => _plan = p)),
                            ),
                        ],
                      ],
                    ),
                  ),
                  if (!managing) _bottomBar(app, tier, upgrading: upgrading),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(PlusTier tier, PlusMembership? membership, {required bool upgrading}) {
    final joined = _joined;
    final String title, text;
    if (joined?.plan == PlusPlan.lifetime) {
      title = 'Bienvenue, Fondateur !';
      text = 'Podium++ est à vous pour toujours, avec le badge exclusif Fondateur. Merci de soutenir Podium !';
    } else if (joined != null) {
      final trialEnd = membership?.trialEndsAt;
      title = 'Bienvenue dans ${joined.tier.label} !';
      text = trialEnd != null ? 'Votre essai gratuit court jusqu’au ${frenchDayMonth(trialEnd)}. Tout est débloqué : à vous de jouer.' : 'Tout est débloqué : à vous de jouer.';
    } else if (upgrading) {
      title = 'Passez à Podium++';
      text = 'Gardez tout Podium+, et personnalisez aussi toute l’interface : thèmes, styles, fonds et polices.';
    } else if (membership != null) {
      title = 'Vous êtes membre ${membership.tier.label}';
      text = membership.tier == PlusTier.plus ? 'Bannières, cadres et effets : toute votre carte est débloquée.' : 'Votre carte et toute l’interface : tout est débloqué.';
    } else if (tier == PlusTier.plus) {
      title = 'Faites briller votre profil';
      text = 'Bannières animées, cadres, polices et effets de pseudo : tout ce qui se voit sur votre carte.';
    } else {
      title = 'Tout Podium, à votre façon';
      text = 'Votre carte, et toute l’interface : thèmes, styles, fonds et polices de l’app.';
    }
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Column(
      children: [
        // The mark pops in — and again on joining, or on changing tier.
        TweenAnimationBuilder<double>(
          key: ValueKey((joined, tier)),
          tween: Tween(begin: still ? 1 : 0.55, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.elasticOut,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: PlusWordmark(size: 34, tier: tier),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: appSwitchTransition,
          child: Column(
            key: ValueKey(title),
            children: [
              Text(title, textAlign: TextAlign.center, style: bodyFont(size: 23, weight: FontWeight.w800, color: Colors.white, height: 1.15, letterSpacing: -0.3)),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center, style: bodyFont(size: 14, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.72), height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _preview(AppUser? me, PlusTier tier) {
    final look = widget.previewLook;
    if (look != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: AspectRatio(
            aspectRatio: AppearancePreview.designSize.aspectRatio,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
                boxShadow: [BoxShadow(color: kPlusGradient[2].withValues(alpha: 0.45), blurRadius: 32, offset: const Offset(0, 12))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox.fromSize(size: AppearancePreview.designSize, child: AppearancePreview(tokens: AppTokens.resolve(look, dark: widget.previewDark))),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final base = widget.preview ?? (me == null ? null : (me.isPlus || me.paidPicks.isNotEmpty ? me : _dressedUp(me)));
    if (base == null) return const SizedBox.shrink();
    final card = base.copyWith(
      // Shown off wearing the mark of the tier on show.
      plus: () => _joined != null || base.plus?.tier == tier ? base.plus : PlusMembership(tier: tier, plan: PlusPlan.yearly, since: DateTime(2026)),
      // Joining sets the card off.
      profileEffect: () => _joined != null ? (base.profileEffect ?? 'fireworks') : base.profileEffect,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: LayoutBuilder(
        builder: (context, box) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(width: box.maxWidth, child: ProfileHeaderCard(user: card, subtitle: me?.isPlus == true ? 'Votre carte' : 'Avec ${tier.label}', effectReplayToken: _joined)),
        ),
      ),
    );
  }

  /// The player's own card in a few paid picks.
  static AppUser _dressedUp(AppUser me) => me.copyWith(banner: 'aurora', avatarFrame: () => 'neon', nameEffect: () => 'holo', profileEffect: () => 'shooting');

  Widget _bottomBar(AppState app, PlusTier tier, {required bool upgrading}) {
    final joined = _joined != null;
    final offer = _offer(tier, _plan, upgrade: upgrading);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      decoration: BoxDecoration(
        color: kPlusNight.withValues(alpha: 0.88),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlusButton(
            label: joined ? 'Continuer' : offer.cta,
            loading: _buying,
            onTap: joined ? () => Navigator.of(context).pop(PlusOutcome.joined) : () => _buy(app),
          ),
          if (!joined) ...[
            const SizedBox(height: 9),
            Text(offer.fine, textAlign: TextAlign.center, style: bodyFont(size: 12, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6))),
            const SizedBox(height: 2),
            Text('Simulation : aucun paiement n’est effectué.', textAlign: TextAlign.center, style: bodyFont(size: 11.5, weight: FontWeight.w700, color: kPlusGradient[0].withValues(alpha: 0.9))),
            if (widget.declineLabel != null)
              TextButton(
                onPressed: _buying ? null : () => Navigator.of(context).pop(PlusOutcome.declined),
                child: Text(widget.declineLabel!, style: bodyFont(size: 13.5, weight: FontWeight.w700, color: Colors.white.withValues(alpha: _buying ? 0.35 : 0.8))),
              ),
          ],
        ],
      ),
    );
  }
}

/// Podium+ or Podium++, side by side: what each covers and from how much.
class _TierSwitch extends StatelessWidget {
  final PlusTier selected;
  final ValueChanged<PlusTier>? onPick;
  const _TierSwitch({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    Widget card(PlusTier tier, String what, String from) {
      final on = tier == selected;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: Pressable(
            onTap: onPick == null ? null : () => onPick!(tier),
            pressedScale: 0.97,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(1.8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                gradient: LinearGradient(colors: on ? kPlusGradient : [for (final _ in kPlusGradient) Colors.white.withValues(alpha: 0.12)]),
                boxShadow: [BoxShadow(color: kPlusGradient[1].withValues(alpha: on ? 0.3 : 0), blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(color: Color.lerp(kPlusNight, Colors.white, on ? 0.1 : 0.04), borderRadius: BorderRadius.circular(17.2)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PlusMark(size: 20, rim: false, tier: tier),
                        const SizedBox(width: 8),
                        Flexible(child: Text(tier.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 15, weight: FontWeight.w800, color: Colors.white))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(what, style: bodyFont(size: 12, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.75), height: 1.25)),
                    const SizedBox(height: 4),
                    Text(from, style: bodyFont(size: 11.5, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card(PlusTier.plus, 'Votre carte de profil', 'dès 1,67 € par mois'),
          const SizedBox(width: 10),
          card(PlusTier.plusPlus, 'La carte et toute l’interface', 'dès 2,50 € par mois'),
        ],
      ),
    );
  }
}

// ============================== pieces ==============================

/// Says, at the top of the page, that nothing is really being sold yet.
class _SimulationTag extends StatelessWidget {
  const _SimulationTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: kPlusGradient[0].withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kPlusGradient[0].withValues(alpha: 0.5)),
      ),
      child: Text('SIMULATION', style: bodyFont(size: 10.5, weight: FontWeight.w800, color: kPlusGradient[0], letterSpacing: 0.9)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 12),
        child: Text(text.toUpperCase(), style: bodyFont(size: 11.5, weight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.55), letterSpacing: 0.9)),
      );
}

/// A see-through panel on the night sky.
class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }
}

typedef _Perk = ({String? emoji, PlusTier? mark, String title, String text});

/// What a tier unlocks, two by two — counted from lib/logic/plus.dart, so
/// the page follows the free/paid split by itself.
class _Perks extends StatelessWidget {
  final List<_Perk> perks;
  const _Perks({required this.perks});

  static String _some(Iterable<String> labels) => '${labels.take(4).join(', ')}…';

  /// Podium+'s: the profile card — with the mark of [tier] last.
  static List<_Perk> card(PlusTier tier) => [
        (emoji: '🌌', mark: null, title: '${kPlusBanners.length} bannières animées', text: _some(kBannerThemes.where((b) => kPlusBanners.contains(b.id)).map((b) => b.label))),
        (emoji: '💫', mark: null, title: '${kPlusAvatarFrames.length} cadres d’avatar', text: _some(kAvatarFrames.where((f) => kPlusAvatarFrames.contains(f.id)).map((f) => f.label))),
        (emoji: '✨', mark: null, title: '${kPlusNameEffects.length} effets et ${kPlusNameFonts.length} polices de pseudo', text: _some(kNameEffects.where((e) => kPlusNameEffects.contains(e.id)).map((e) => e.label))),
        (emoji: '🎆', mark: null, title: '${kPlusProfileEffects.length} effets de profil', text: _some(kProfileEffects.where((e) => kPlusProfileEffects.contains(e.id)).map((e) => e.label))),
        (emoji: null, mark: tier, title: 'La marque ${tier.label}', text: 'À côté de votre pseudo, sur votre carte de profil.'),
      ];

  /// What Podium++ adds: the whole interface.
  static List<_Perk> interface() => [
        (emoji: '🎨', mark: null, title: '${kShopThemes.length} thèmes pour l’app', text: _some(kShopThemes.map((t) => t.label))),
        (emoji: '🪟', mark: null, title: '${kPlusSurfaces.length} styles d’interface', text: _some(kPlusSurfaces.map((s) => s.label))),
        (emoji: '🌠', mark: null, title: '${kPlusBackdrops.length} fonds d’écran', text: '${_some(kPlusBackdrops.map((b) => b.label))} Animés pour la plupart.'),
        (emoji: '🔤', mark: null, title: '${kPlusFonts.length} polices pour l’app', text: _some(kPlusFonts.map((f) => f.label))),
        (emoji: '🌈', mark: null, title: 'La couleur sur mesure', text: 'Toutes les teintes, pour les boutons et les accents.'),
      ];

  @override
  Widget build(BuildContext context) {
    Widget tile(int i) {
      final perk = perks[i];
      return FadeSlideIn(
        delay: staggerDelay(i, baseMs: 120, stepMs: 45),
        child: _Panel(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 28,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: perk.mark != null ? PlusMark(size: 24, rim: false, tier: perk.mark!) : Text(perk.emoji ?? '', style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(height: 8),
              Text(perk.title, style: bodyFont(size: 13.5, weight: FontWeight.w800, color: Colors.white, height: 1.2)),
              const SizedBox(height: 4),
              Text(perk.text, style: bodyFont(size: 11.5, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6), height: 1.3)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < perks.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tile(i)),
                  const SizedBox(width: 10),
                  Expanded(child: i + 1 < perks.length ? tile(i + 1) : const SizedBox()),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One plan to pick: its name, what it comes with, its price.
class _PlanTile extends StatelessWidget {
  final _Offer offer;
  final bool selected;
  final VoidCallback? onTap;
  const _PlanTile({required this.offer, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.98,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(1.8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            gradient: LinearGradient(colors: selected ? kPlusGradient : [for (final _ in kPlusGradient) Colors.white.withValues(alpha: 0.12)]),
            boxShadow: [BoxShadow(color: kPlusGradient[1].withValues(alpha: selected ? 0.32 : 0), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(color: Color.lerp(kPlusNight, Colors.white, selected ? 0.1 : 0.05), borderRadius: BorderRadius.circular(17.2)),
            child: Row(
              children: [
                _Tick(selected: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(offer.title, style: bodyFont(size: 15, weight: FontWeight.w800, color: Colors.white)),
                          if (offer.tag != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), gradient: const LinearGradient(colors: kPlusGradient)),
                              child: Text(offer.tag!, style: bodyFont(size: 10.5, weight: FontWeight.w800, color: Colors.white)),
                            ),
                        ],
                      ),
                      if (offer.detail != null) ...[
                        const SizedBox(height: 3),
                        Text(offer.detail!, style: bodyFont(size: 12, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.62))),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(offer.price, style: dispFont(size: 18, weight: FontWeight.w700, color: Colors.white)),
                    Text(offer.per, style: bodyFont(size: 11, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The round tick of a plan: an empty ring, or the gradient with a check.
class _Tick extends StatelessWidget {
  final bool selected;
  const _Tick({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: kPlusGradient) : null,
        border: selected ? null : Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.6),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
      ),
    );
  }
}

/// The page's call to action, in Podium+'s gradient.
class _PlusButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _PlusButton({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !loading,
      child: Pressable(
        onTap: loading ? null : onTap,
        pressedScale: 0.97,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 54),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: kPlusGradient),
            boxShadow: [BoxShadow(color: kPlusGradient[1].withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: loading
                ? const SizedBox(key: ValueKey('loading'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(label, key: ValueKey(label), textAlign: TextAlign.center, style: bodyFont(size: 16, weight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

/// A member's plan, dates, the way up to Podium++ for a Podium+ one, and
/// the way out.
class _MembershipCard extends StatelessWidget {
  final PlusMembership membership;
  final VoidCallback onCancel;
  final VoidCallback? onUpgrade;
  const _MembershipCard({required this.membership, required this.onCancel, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final next = membership.nextPayment(now);
    final lifetime = membership.plan == PlusPlan.lifetime;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: Text(label, style: bodyFont(size: 13.5, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.65)))),
              const SizedBox(width: 12),
              Text(value, style: bodyFont(size: 13.5, weight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        );
    return _Panel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PlusMark(size: 24, rim: false, tier: membership.tier),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lifetime ? 'Fondateur · à vie' : '${membership.tier.label} · ${membership.plan.label.toLowerCase()}',
                  style: bodyFont(size: 16, weight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          row('Membre depuis le', _longDate(membership.since)),
          if (membership.inTrial(now)) row('Essai gratuit jusqu’au', _longDate(membership.trialEndsAt!)),
          if (next != null) row('Prochain paiement', '${_longDate(next)} · ${_offer(membership.tier, membership.plan).price}'),
          if (onUpgrade != null) ...[
            const SizedBox(height: 10),
            Pressable(
              onTap: onUpgrade,
              child: Container(
                padding: const EdgeInsets.all(1.4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(15.4), gradient: const LinearGradient(colors: kPlusGradient)),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: kPlusNight),
                  child: Row(
                    children: [
                      const PlusMark(size: 20, rim: false, tier: PlusTier.plusPlus),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Passer à Podium++', style: bodyFont(size: 14, weight: FontWeight.w800, color: Colors.white)),
                            Text('Toute l’interface en plus de votre carte', style: bodyFont(size: 12, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.8)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), visualDensity: VisualDensity.compact),
              child: Text(lifetime ? 'Retirer ${membership.tier.label}' : 'Résilier l’abonnement', style: bodyFont(size: 13.5, weight: FontWeight.w800, color: const Color(0xFFFF8F8F))),
            ),
          ),
        ],
      ),
    );
  }
}

/// The page's backdrop: the brand's three colours glowing and drifting on
/// a night sky, with stars twinkling.
class _NightSky extends StatelessWidget {
  const _NightSky();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AmbientLoop(
        period: const Duration(seconds: 18),
        builder: (context, ph) => CustomPaint(painter: _SkyPainter(ph), size: Size.infinite),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  final double ph;
  _SkyPainter(this.ph);

  static const _glows = [
    (x: 0.12, y: 0.06, r: 0.8, alpha: 0.3, seed: 0.0),
    (x: 0.92, y: 0.2, r: 0.7, alpha: 0.28, seed: 0.33),
    (x: 0.35, y: 0.62, r: 0.95, alpha: 0.22, seed: 0.66),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width, h = size.height;
    for (final (i, g) in _glows.indexed) {
      final c = Offset(w * (g.x + 0.07 * wave(ph, g.seed)), h * (g.y + 0.04 * wave(ph, g.seed + 0.25)));
      final r = w * g.r;
      final color = kPlusGradient[i];
      canvas.drawCircle(c, r, Paint()..shader = ui.Gradient.radial(c, r, [color.withValues(alpha: g.alpha), color.withValues(alpha: 0)]));
    }
    final star = Paint();
    for (var i = 0; i < 48; i++) {
      final p = Offset(hash01(i * 3.1 + 0.5) * w, hash01(i * 7.7 + 1.3) * h);
      final twinkle = wave01(ph, hash01(i * 5.3), 2);
      star.color = Colors.white.withValues(alpha: 0.12 + 0.5 * twinkle * hash01(i * 1.9 + 4));
      canvas.drawCircle(p, 0.6 + 1.1 * hash01(i * 2.3 + 2), star);
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.ph != ph;
}
