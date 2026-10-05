import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Whether an avatar's `initial` is an emoji rather than a letter — letters
/// (accented ones included) all sit well below U+2000.
bool isEmojiAvatar(String initial) => initial.runes.any((r) => r >= 0x2000);

/// Colored circle with a player's initial — used everywhere from the 30px
/// header cluster to the 72px profile header.
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
      child: isEmojiAvatar(initial)
          // A chosen avatar emoji (see AppUser.avatarEmoji) reads best a
          // little larger than a letter.
          ? Text(initial, style: TextStyle(fontSize: size * 0.5, height: 1.1))
          : Text(
              initial,
              style: bodyFont(size: fontSize ?? size * 0.4, weight: FontWeight.w800, color: Colors.white),
            ),
    );
  }
}

/// The overlapping avatar cluster in the home header.
class AvatarCluster extends StatelessWidget {
  final List<({String initial, Color color})> avatars;
  const AvatarCluster({super.key, required this.avatars});

  @override
  Widget build(BuildContext context) {
    const size = 30.0;
    const overlap = 9.0;
    return SizedBox(
      height: size,
      width: avatars.isEmpty ? 0 : size + (avatars.length - 1) * (size - overlap),
      child: Stack(
        children: [
          for (var i = 0; i < avatars.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Avatar(
                initial: avatars[i].initial,
                color: avatars[i].color,
                size: size,
                fontSize: 12,
                borderColor: AppColors.bg,
                borderWidth: 2.5,
              ),
            ),
        ],
      ),
    );
  }
}
