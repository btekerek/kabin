import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/core/listener/listener_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // In-memory fake backing SharedPreferences.getInstance() - no real
    // platform channel needed under plain flutter_test.
    SharedPreferences.setMockInitialValues({});
  });

  group('ListenerIdentity', () {
    test('generates a uuid on first call and persists it', () async {
      final identity = ListenerIdentity();
      final first = await identity.getOrCreate();
      final second = await identity.getOrCreate();

      expect(first, isNotEmpty);
      expect(second, first);
    });

    test('a fresh instance reads back the same persisted uuid', () async {
      final generated = await ListenerIdentity().getOrCreate();
      final reread = await ListenerIdentity().getOrCreate();

      expect(reread, generated);
    });
  });
}
