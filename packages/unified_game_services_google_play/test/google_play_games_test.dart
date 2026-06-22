@TestOn('!browser')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:unified_game_services_google_play/unified_game_services_google_play.dart';

/// Minimal non-interactive auth strategy for selection tests.
class _FakeAuth implements AuthStrategy {
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async => 'tok';
  @override
  bool get isAuthenticated => true;
  @override
  Future<void> signOut() async {}
}

void main() {
  group('GooglePlayGames.create', () {
    test('usesNative matches Platform.isAndroid', () {
      expect(GooglePlayGames.usesNative, Platform.isAndroid);
    });

    // These run on the host (desktop/CI), i.e. the non-Android branch.
    test(
      'off Android, builds the REST provider from an AuthStrategy',
      () {
        final p = GooglePlayGames.create(auth: _FakeAuth());
        expect(p, isA<GooglePlayGamesProvider>());
      },
      testOn: '!android',
    );

    test('off Android, throws without an AuthStrategy', () {
      expect(() => GooglePlayGames.create(), throwsArgumentError);
    }, testOn: '!android');
  });
}
