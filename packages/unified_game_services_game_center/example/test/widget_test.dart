import 'package:flutter_test/flutter_test.dart';

import 'package:game_center_example/main.dart';

void main() {
  testWidgets('renders the example shell', (tester) async {
    await tester.pumpWidget(const GameCenterExampleApp());

    expect(find.text('Game Center Example'), findsOneWidget);
    expect(find.text('Authenticate (window)'), findsOneWidget);
    expect(find.text('Show dashboard (window)'), findsOneWidget);
  });
}
