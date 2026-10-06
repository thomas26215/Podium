// The illustrated avatars (lib/widgets/avatar_art.dart): every one picked is
// drawn and paints, and the Avatar widget shows it — or the initial.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:podium/widgets/avatar.dart';
import 'package:podium/widgets/avatar_art.dart';
import 'package:podium/widgets/avatar_art_data.dart';

void main() {
  final ids = [for (final c in kAvatarCollections) ...c.ids];

  test('every avatar picked is drawn, once — and nothing else is', () {
    expect(ids.toSet(), hasLength(ids.length), reason: 'no avatar in two collections');
    expect(kAvatarArt.keys.toSet(), ids.toSet(), reason: 'run tool/avatars.dart after changing a collection');
    expect(avatarCollectionOf('critters/14')?.label, 'Créatures');
    expect(avatarCollectionOf(null), isNull);
  });

  test('each collection credits who drew it, and the licence', () {
    for (final c in kAvatarCollections) {
      expect(c.credit, anyOf(contains('CC BY 4.0'), contains('CC0')), reason: c.label);
    }
    expect(kAvatarCollections.firstWhere((c) => c.style == 'adventurer').credit, contains('Lisa Wischofsky'));
  });

  testWidgets('every avatar paints', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SingleChildScrollView(
        child: Wrap(children: [for (final id in ids) AvatarArt(id: id, size: 40)]),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(AvatarArt), findsNWidgets(ids.length));
  });

  testWidgets('the avatar circle shows the one picked, else the initial', (tester) async {
    Future<void> show(String initial) => tester.pumpWidget(MaterialApp(home: Center(child: Avatar(initial: initial, color: Colors.teal))));

    await show('critters/14');
    expect(find.byWidgetPredicate((w) => w is AvatarArt && w.id == 'critters/14'), findsOneWidget);
    await show('L');
    expect(find.text('L'), findsOneWidget);
    expect(find.byType(AvatarArt), findsNothing);
    await show('dragons/3');
    expect(find.byIcon(Icons.person_rounded), findsOneWidget, reason: 'an avatar from a newer version of the app');
  });
}
