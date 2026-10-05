import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GamePlatform {
  final String id;
  final String label;
  final String short;
  final int color;
  final String hint;
  const GamePlatform(this.id, this.label, this.short, this.color, this.hint);
}

/// Platforms a player can list their handle for (see AppUser.gameAccounts).
const kGamePlatforms = [
  GamePlatform('steam', 'Steam', 'ST', 0xFF1B2838, 'Pseudo Steam'),
  GamePlatform('playstation', 'PlayStation', 'PS', 0xFF003791, 'ID en ligne PSN'),
  GamePlatform('xbox', 'Xbox', 'XB', 0xFF107C10, 'Gamertag'),
  GamePlatform('switch', 'Nintendo Switch', 'NS', 0xFFE60012, 'Code ami (SW-0000-0000-0000)'),
  GamePlatform('epic', 'Epic Games', 'EG', 0xFF313131, 'Pseudo Epic'),
  GamePlatform('riot', 'Riot Games', 'RG', 0xFFD13639, 'Riot ID (Nom#TAG)'),
  GamePlatform('discord', 'Discord', 'DC', 0xFF5865F2, 'Pseudo Discord'),
  GamePlatform('bga', 'Board Game Arena', 'BGA', 0xFF3E7CB1, 'Pseudo BGA'),
  GamePlatform('bgg', 'BoardGameGeek', 'BGG', 0xFFFF5100, 'Pseudo BGG'),
  GamePlatform('chesscom', 'Chess.com', '♞', 0xFF5D8A3A, 'Pseudo Chess.com'),
];

GamePlatform? gamePlatformById(String id) {
  for (final p in kGamePlatforms) {
    if (p.id == id) return p;
  }
  return null;
}

/// A platform's little logo tile: its brand colour with a short mark.
class PlatformLogo extends StatelessWidget {
  final GamePlatform platform;
  final double size;
  const PlatformLogo({super.key, required this.platform, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Color(platform.color), borderRadius: BorderRadius.circular(size * 0.28)),
      child: FittedBox(
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: Text(platform.short, style: dispFont(size: size * 0.42, weight: FontWeight.w800, color: Colors.white)),
        ),
      ),
    );
  }
}
