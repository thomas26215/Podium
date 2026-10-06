import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// What a membership unlocks (see lib/logic/plus.dart).
enum PlusTier {
  /// Every paid cosmetic of the profile card.
  plus('Podium+'),

  /// All of Podium+, and the app's whole interface too: themes, styles,
  /// backgrounds, fonts and the made-to-measure colour.
  plusPlus('Podium++');

  const PlusTier(this.label);
  final String label;
}

/// The ways to hold a membership (see PlusScreen for what each costs).
enum PlusPlan {
  monthly('Mensuel'),
  yearly('Annuel'),

  /// Paid once, kept for good — the launch offer, Podium++ only.
  lifetime('Fondateur');

  const PlusPlan(this.label);
  final String label;
}

/// A player's Podium+ or Podium++ membership — on their public profile doc
/// (`plus`), so every other player's app knows to show their paid
/// cosmetics (see lib/logic/plus.dart).
///
/// SIMULATION: for now the app writes it itself when the player "buys" a
/// plan, and no payment is taken. Once purchases are real, only the server
/// will write it, from the store's receipts, and firestore.rules will
/// refuse it from the app.
@immutable
class PlusMembership {
  final PlusTier tier;
  final PlusPlan plan;
  final DateTime since;

  /// When the free week a yearly plan opens on ends — null without one.
  final DateTime? trialEndsAt;

  const PlusMembership({this.tier = PlusTier.plus, required this.plan, required this.since, this.trialEndsAt});

  bool inTrial(DateTime now) => trialEndsAt != null && now.isBefore(trialEndsAt!);

  /// When it's next paid for, after [now]: at the end of the trial, then
  /// every month or year from there — null for a lifetime plan.
  DateTime? nextPayment(DateTime now) {
    final months = switch (plan) { PlusPlan.monthly => 1, PlusPlan.yearly => 12, PlusPlan.lifetime => 0 };
    if (months == 0) return null;
    final start = trialEndsAt ?? since;
    for (var k = trialEndsAt != null ? 0 : 1;; k++) {
      final next = _addMonths(start, k * months);
      if (next.isAfter(now)) return next;
    }
  }

  /// [d] moved [months] on, on the same day — or the month's last one
  /// when it's shorter (31 Jan → 28 Feb).
  static DateTime _addMonths(DateTime d, int months) {
    final firstOfMonth = DateTime(d.year, d.month + months);
    final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
    return DateTime(firstOfMonth.year, firstOfMonth.month, d.day > lastDay ? lastDay : d.day, d.hour, d.minute);
  }

  Map<String, Object> toMap() => {
        'tier': tier.name,
        'plan': plan.name,
        'since': Timestamp.fromDate(since),
        if (trialEndsAt != null) 'trialEndsAt': Timestamp.fromDate(trialEndsAt!),
      };

  /// Null for anything unreadable — no membership rather than a broken one.
  static PlusMembership? fromMap(Object? data) {
    if (data is! Map) return null;
    final plan = PlusPlan.values.where((p) => p.name == data['plan']).firstOrNull;
    final since = _date(data['since']);
    if (plan == null || since == null) return null;
    // From before the tiers, a membership was Podium+.
    final tier = PlusTier.values.where((t) => t.name == data['tier']).firstOrNull ?? PlusTier.plus;
    return PlusMembership(tier: tier, plan: plan, since: since, trialEndsAt: _date(data['trialEndsAt']));
  }

  static DateTime? _date(Object? v) => switch (v) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        _ => null,
      };

  @override
  bool operator ==(Object other) => other is PlusMembership && other.tier == tier && other.plan == plan && other.since == since && other.trialEndsAt == trialEndsAt;

  @override
  int get hashCode => Object.hash(tier, plan, since, trialEndsAt);
}
