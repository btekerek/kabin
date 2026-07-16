import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/core/agora/agora_join_result.dart';

void main() {
  group('AgoraJoinResult.fromJson', () {
    test('parses the shape shared by every join endpoint', () {
      final result = AgoraJoinResult.fromJson({
        'agora_app_id': 'app-123',
        'agora_channel_name': 'chan-abc',
        'agora_token': 'token-xyz',
        'expires_in': 3600,
        // Extra fields like `channel` are ignored here - each caller
        // (listener/interpreter repository) parses that part itself,
        // since its shape differs between the two roles.
        'channel': {'id': 1},
      });

      expect(result.agoraAppId, 'app-123');
      expect(result.agoraChannelName, 'chan-abc');
      expect(result.agoraToken, 'token-xyz');
      expect(result.expiresIn, 3600);
    });
  });
}
