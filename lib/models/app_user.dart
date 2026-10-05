import 'package:cloud_firestore/cloud_firestore.dart';

/// Palette a new account is assigned from, deterministically, so avatars
/// stay stable across sessions without needing a color picker at signup.
const List<int> kAvatarPalette = [
  0xFFFF5B34,
  0xFF5B4BE8,
  0xFF1F9D57,
  0xFFE8A93B,
  0xFFE5537B,
  0xFF2AA8B0,
  0xFF8B5CF6,
  0xFFD9622B,
];

/// How many unlocked badges a player can pin under their name.
const kMaxShowcasedBadges = 3;

const kDefaultBanner = 'nuit';

int colorForUid(String uid) {
  var hash = 0;
  for (final unit in uid.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return kAvatarPalette[hash % kAvatarPalette.length];
}

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final int color;
  /// True for a player added without a real account (see [GuestsRepository]).
  /// Its `uid` is a `guest:<id>` string rather than a Firebase Auth uid.
  final bool isGuest;

  /// Uids of this account's friends — a personal, one-directional address
  /// book (adding someone doesn't require their consent, same trust model
  /// as inviting a member into a group) used to prefill the group-invite
  /// picker instead of typing an e-mail every time (see
  /// [AppState.addFriend]/[AppState.friends]).
  final List<String> friendIds;

  // ---- profile customization (all public — see [toProfileMap]) ----

  /// A short free-text line under the name on the profile.
  final String bio;

  /// An emoji shown in the avatar instead of the name's initial (see
  /// [initial]) — null for the plain initial.
  final String? avatarEmoji;

  /// Which banner theme the profile card uses (see `kBannerThemes` in
  /// lib/widgets/profile_banners.dart) — a plain gradient or a game-themed
  /// scene.
  final String banner;

  /// The decoration around the avatar on the profile card (see
  /// `kAvatarFrames`), or null for none.
  final String? avatarFrame;

  /// Ids of every badge this account has unlocked (see lib/logic/badges.dart)
  /// — only ever grows, so a badge earned in one group stays earned when
  /// the player is looking at another.
  final List<String> badges;

  /// Up to [kMaxShowcasedBadges] of [badges], picked by the player to sit
  /// under their name.
  final List<String> showcasedBadges;

  /// The games this player owns, as ids in the shared game library (see
  /// GameLibraryRepository) — their "collection".
  final List<String> ownedGameIds;

  /// A library game id, shown as "Jeu préféré" on the profile.
  final String? favoriteGameId;

  /// Free text shown next to the name (e.g. "elle", "il/lui").
  final String pronouns;

  /// A Discord-style custom status: an optional emoji plus a short line
  /// ("Partant pour un Catan ce soir"), shown as a bubble on the card.
  final String status;
  final String? statusEmoji;

  /// A title shown under the name — one of `kTitles` (lib/logic/badges.dart),
  /// most of them unlocked by a badge.
  final String? titleId;

  /// How the name is drawn on the card: a font (`kNameFonts`) and an effect
  /// (`kNameEffects`), both in lib/widgets/profile_style.dart. Null = the
  /// app's default.
  final String? nameFont;
  final String? nameEffect;

  /// A one-shot animation played over the card when the profile opens
  /// (`kProfileEffects`) — null for none.
  final String? profileEffect;

  /// Game platform handles shown on the profile, keyed by a `kGamePlatforms`
  /// id: `{'steam': 'lea_42', 'switch': 'SW-1234-5678-9012'}`.
  final Map<String, String> gameAccounts;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.color,
    this.isGuest = false,
    this.friendIds = const [],
    this.bio = '',
    this.avatarEmoji,
    this.banner = kDefaultBanner,
    this.avatarFrame,
    this.badges = const [],
    this.showcasedBadges = const [],
    this.ownedGameIds = const [],
    this.favoriteGameId,
    this.pronouns = '',
    this.status = '',
    this.statusEmoji,
    this.titleId,
    this.nameFont,
    this.nameEffect,
    this.profileEffect,
    this.gameAccounts = const {},
  });

  /// What the avatar shows: the chosen emoji, else the name's first letter.
  String get initial => avatarEmoji ?? letter;

  /// The name's first letter, regardless of any [avatarEmoji].
  String get letter => displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

  AppUser copyWith({
    String? displayName,
    int? color,
    List<String>? friendIds,
    String? bio,
    String? Function()? avatarEmoji,
    String? banner,
    String? Function()? avatarFrame,
    List<String>? badges,
    List<String>? showcasedBadges,
    List<String>? ownedGameIds,
    String? Function()? favoriteGameId,
    String? pronouns,
    String? status,
    String? Function()? statusEmoji,
    String? Function()? titleId,
    String? Function()? nameFont,
    String? Function()? nameEffect,
    String? Function()? profileEffect,
    Map<String, String>? gameAccounts,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      color: color ?? this.color,
      isGuest: isGuest,
      friendIds: friendIds ?? this.friendIds,
      bio: bio ?? this.bio,
      avatarEmoji: avatarEmoji != null ? avatarEmoji() : this.avatarEmoji,
      banner: banner ?? this.banner,
      avatarFrame: avatarFrame != null ? avatarFrame() : this.avatarFrame,
      badges: badges ?? this.badges,
      showcasedBadges: showcasedBadges ?? this.showcasedBadges,
      ownedGameIds: ownedGameIds ?? this.ownedGameIds,
      favoriteGameId: favoriteGameId != null ? favoriteGameId() : this.favoriteGameId,
      pronouns: pronouns ?? this.pronouns,
      status: status ?? this.status,
      statusEmoji: statusEmoji != null ? statusEmoji() : this.statusEmoji,
      titleId: titleId != null ? titleId() : this.titleId,
      nameFont: nameFont != null ? nameFont() : this.nameFont,
      nameEffect: nameEffect != null ? nameEffect() : this.nameEffect,
      profileEffect: profileEffect != null ? profileEffect() : this.profileEffect,
      gameAccounts: gameAccounts ?? this.gameAccounts,
    );
  }

  /// The customizable part of the public doc, written by
  /// UsersRepository.updateProfile. Badges are left out on purpose: they're
  /// only ever added through UsersRepository.unlockBadges.
  Map<String, dynamic> toProfileMap() => {
        'displayName': displayName,
        'color': color,
        'bio': bio,
        'avatarEmoji': avatarEmoji,
        'banner': banner,
        'avatarFrame': avatarFrame,
        'showcasedBadges': showcasedBadges,
        'ownedGameIds': ownedGameIds,
        'favoriteGameId': favoriteGameId,
        'pronouns': pronouns,
        'status': status,
        'statusEmoji': statusEmoji,
        'titleId': titleId,
        'nameFont': nameFont,
        'nameEffect': nameEffect,
        'profileEffect': profileEffect,
        'gameAccounts': gameAccounts,
      };

  /// The public `users/{uid}` doc — readable by every signed-in account, so
  /// it only holds what other players need to see (see firestore.rules).
  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'color': color,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// The owner-only `users/{uid}/private/account` doc — everything about the
  /// account that other players must not be able to read.
  Map<String, dynamic> toPrivateMap() => {
        'email': email,
        'friendIds': friendIds,
      };

  /// Builds a user from its public doc, plus its [private] doc when reading
  /// the signed-in account itself. A public doc from before the split may
  /// still carry `email`/`friendIds` itself — read as a fallback until it's
  /// migrated (see UsersRepository.watchOwnAccount).
  factory AppUser.fromDoc(String uid, Map<String, dynamic> data, {Map<String, dynamic>? private}) {
    final p = private ?? const {};
    return AppUser(
      uid: uid,
      email: (p['email'] as String?) ?? (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? 'Joueur',
      color: (data['color'] as int?) ?? colorForUid(uid),
      friendIds: List<String>.from((p['friendIds'] as List?) ?? (data['friendIds'] as List?) ?? const []),
      bio: (data['bio'] as String?) ?? '',
      avatarEmoji: _nonEmpty(data['avatarEmoji']),
      banner: (data['banner'] as String?) ?? kDefaultBanner,
      avatarFrame: data['avatarFrame'] as String?,
      badges: List<String>.from((data['badges'] as List?) ?? const []),
      showcasedBadges: List<String>.from((data['showcasedBadges'] as List?) ?? const []),
      ownedGameIds: List<String>.from((data['ownedGameIds'] as List?) ?? const []),
      favoriteGameId: data['favoriteGameId'] as String?,
      pronouns: (data['pronouns'] as String?) ?? '',
      status: (data['status'] as String?) ?? '',
      statusEmoji: _nonEmpty(data['statusEmoji']),
      titleId: _nonEmpty(data['titleId']),
      nameFont: _nonEmpty(data['nameFont']),
      nameEffect: _nonEmpty(data['nameEffect']),
      profileEffect: _nonEmpty(data['profileEffect']),
      gameAccounts: {
        for (final e in ((data['gameAccounts'] as Map?) ?? const {}).entries)
          if (e.key is String && e.value is String && (e.value as String).trim().isNotEmpty) e.key as String: e.value as String,
      },
    );
  }

  /// A doc string field, with "" read back as null.
  static String? _nonEmpty(Object? v) => v is String && v.isNotEmpty ? v : null;
}
