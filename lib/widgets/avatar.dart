import 'package:flutter/material.dart';

import '../logic/plus.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import 'avatar_art.dart';
import 'avatar_frames.dart';

/// Colored circle with a player's avatar (see AppUser.initial): the one
/// they picked, else their initial — used everywhere from the 30px header
/// cluster to the 72px profile header.
class Avatar extends StatelessWidget {
  final String initial;
  final Color color;
  final double size;
  final double? fontSize;
  final Color? borderColor;
  final double borderWidth;

  const Avatar({
    super.key,
    required this.initial,
    required this.color,
    this.size = 38,
    this.fontSize,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: borderColor != null ? Border.all(color: borderColor!, width: borderWidth) : null,
      ),
      child: switch (initial) {
        _ when isAvatarArt(initial) => ClipOval(child: AvatarArt(id: initial, size: size - (borderColor != null ? 2 * borderWidth : 0))),
        // An avatar this version of the app doesn't have yet.
        _ when initial.length > 2 => Icon(Icons.person_rounded, size: size * 0.62, color: Colors.white),
        _ => Text(
            initial,
            style: bodyFont(size: fontSize ?? size * 0.4, weight: FontWeight.w800, color: Colors.white),
          ),
      },
    );
  }
}

/// [user]'s [Avatar] in the decoration they picked for their card (see
/// AppUser.avatarFrame, as everyone sees it — PlusProfile.shown): how a
/// player shows up everywhere, not just on their profile. A null [user]
/// (not loaded yet, or gone) is a grey "?".
///
/// The decoration holds still unless [live]: a list of framed players
/// costs a paint each, and only spotlights (the leader, the podium) play
/// it. It reaches past [size] without taking room, so it drops into a row
/// laid out for the bare avatar.
class PlayerAvatar extends StatelessWidget {
  final AppUser? user;
  final double size;
  final double? fontSize;
  final bool live;
  final Color? borderColor;
  final double borderWidth;
  const PlayerAvatar(this.user, {super.key, this.size = 38, this.fontSize, this.live = false, this.borderColor, this.borderWidth = 0});

  @override
  Widget build(BuildContext context) {
    final u = user;
    final avatar = Avatar(initial: u?.initial ?? '?', color: u == null ? AppColors.mut : Color(u.color), size: size, fontSize: fontSize, borderColor: borderColor, borderWidth: borderWidth);
    final frame = u?.shown.avatarFrame;
    if (frame == null) return avatar;
    final reach = size * kFrameReach;
    return SizedBox.square(
      dimension: size,
      child: OverflowBox(
        minWidth: reach,
        maxWidth: reach,
        minHeight: reach,
        maxHeight: reach,
        child: FramedAvatar(frameId: frame, size: size, phase: live ? null : kStillFramePhase, child: avatar),
      ),
    );
  }
}

/// The overlapping avatars of a few players — the home header, a match.
class AvatarCluster extends StatelessWidget {
  final List<AppUser> players;
  const AvatarCluster({super.key, required this.players});

  @override
  Widget build(BuildContext context) {
    const size = 30.0;
    const overlap = 9.0;
    return SizedBox(
      height: size,
      width: players.isEmpty ? 0 : size + (players.length - 1) * (size - overlap),
      child: Stack(
        // Decorations reach past their avatars.
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < players.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: PlayerAvatar(players[i], size: size, fontSize: 12, borderColor: AppColors.bg, borderWidth: 2.5),
            ),
        ],
      ),
    );
  }
}
