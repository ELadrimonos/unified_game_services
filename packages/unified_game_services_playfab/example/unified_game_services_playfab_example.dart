// Minimal PlayFab provider walkthrough.
//
// Run against a real title with:
//   dart run example/unified_game_services_playfab_example.dart
// after setting PLAYFAB_TITLE_ID and PLAYFAB_CUSTOM_ID in the environment.
import 'dart:io';
import 'dart:typed_data';

import 'package:unified_game_services_playfab/unified_game_services_playfab.dart';

Future<void> main() async {
  final titleId = Platform.environment['PLAYFAB_TITLE_ID'];
  final customId =
      Platform.environment['PLAYFAB_CUSTOM_ID'] ?? 'example-player';
  if (titleId == null) {
    stderr.writeln('Set PLAYFAB_TITLE_ID to run this example.');
    exit(64);
  }

  final provider = PlayFabProvider(
    titleId: titleId,
    customId: customId,
    displayName: 'Example Player',
    // Map a unified leaderboard key to a PlayFab statistic name.
    leaderboardIds: const {'high': 'HighScore'},
  );

  final player = await provider.signIn();
  print('Signed in as ${player?.displayName} (${player?.id})');

  await provider.submitScore(leaderboardId: 'high', score: 4200);
  final board = await provider.getLeaderboard('high');
  for (final e in board.entries) {
    print('#${e.rank} ${e.player.displayName} — ${e.displayScore}');
  }

  await provider.setStat('kills', 10);
  await provider.incrementStat('kills', by: 5);
  print('kills = ${(await provider.getStat('kills'))?.value}');

  await provider.saveData('slot0', Uint8List.fromList([1, 2, 3, 4]));
  final save = await provider.loadData('slot0');
  print('loaded ${save?.metadata.sizeBytes} bytes');

  await provider.dispose();
}
