import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/personal_records.dart';
import 'solo_game_screen.dart';

/// "Records" tab of "Mon espace solo" — the ranking's stand-in: every game
/// and rule played, its record up front; tap one for its progression.
class SoloRecordsScreen extends StatelessWidget {
  const SoloRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 116),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenHeading(eyebrow: 'Mon espace solo', title: 'Mes records'),
          PersonalRecordsList(
            records: app.personalRecords,
            onTap: (r) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SoloGameScreen(gameId: r.game.id, initialRuleId: r.rule.id))),
          ),
        ],
      ),
    );
  }
}
