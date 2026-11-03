import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_demo/app_state.dart';
import 'package:unified_demo/screens/profile_screen.dart';

void main() {
  testWidgets('shows my profile and friends with presence, online first', (
    tester,
  ) async {
    final app = AppState()
      ..currentPlayer = const PlayerProfile(
        id: '1',
        displayName: 'Me',
        title: 'Level 12',
        isOnline: true,
        presence: RichPresence(state: 'In lobby'),
      )
      ..friends = const [
        PlayerProfile(id: '2', displayName: 'Zed', isOnline: false),
        PlayerProfile(
          id: '3',
          displayName: 'Ana',
          isOnline: true,
          presence: RichPresence(state: 'Ranked', details: 'Dust II'),
          extra: {'gameId': 480},
        ),
      ];

    await tester.pumpWidget(MaterialApp(home: ProfileScreen(app: app)));

    expect(find.text('Me'), findsOneWidget);
    expect(find.text('Level 12'), findsOneWidget);
    expect(find.text('Friends (2, 1 online)'), findsOneWidget);
    expect(find.textContaining('Ranked · Dust II'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Ana')).dy,
      lessThan(tester.getTopLeft(find.text('Zed')).dy),
    );
  });
}
