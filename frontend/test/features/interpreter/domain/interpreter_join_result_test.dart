import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/core/agora/agora_join_result.dart';
import 'package:kabin/features/interpreter/domain/interpreter_join_result.dart';
import 'package:kabin/features/sessions/domain/channel.dart';

void main() {
  group('InterpreterJoinResult', () {
    test('combines join credentials with the guide-facing channel shape', () {
      // Mirrors how InterpreterRepository.join builds one from
      // ChannelJoinView's response body.
      final data = {
        'agora_app_id': 'app-123',
        'agora_channel_name': 'chan-abc',
        'agora_token': 'token-xyz',
        'expires_in': 3600,
        'channel': {
          'id': 2,
          'session': 7,
          'session_status': 'not_started',
          'language': 'TR',
          'interpreter_code': 'TR117733',
          'is_source': false,
        },
      };

      final result = InterpreterJoinResult(
        joinResult: AgoraJoinResult.fromJson(data),
        channel: Channel.fromJson(data['channel'] as Map<String, dynamic>),
        relay: null,
        availableRelayChannels: const [],
        availableTargetChannels: const [],
      );

      expect(result.joinResult.agoraChannelName, 'chan-abc');
      expect(result.channel.sessionId, 7);
      expect(result.channel.language, 'TR');
      expect(result.channel.interpreterCode, 'TR117733');
      expect(result.channel.isSource, isFalse);
      expect(result.relay, isNull);
    });

    test('carries a relay when the claimed channel is not the source', () {
      final relayData = {
        'agora_app_id': 'app-123',
        'agora_channel_name': 'chan-source',
        'agora_token': 'token-source',
        'expires_in': 3600,
        'channel': {'id': 1, 'language': 'EN', 'is_source': true},
      };

      final result = InterpreterJoinResult(
        joinResult: const AgoraJoinResult(
          agoraAppId: 'app-123',
          agoraChannelName: 'chan-abc',
          agoraToken: 'token-xyz',
          expiresIn: 3600,
        ),
        channel: const Channel(
          id: 2,
          sessionId: 7,
          sessionStatus: 'not_started',
          language: 'TR',
          interpreterCode: 'TR117733',
          isSource: false,
        ),
        relay: RelayJoinResult.fromJson(relayData),
        availableRelayChannels: const [],
        availableTargetChannels: const [],
      );

      expect(result.relay, isNotNull);
      expect(result.relay!.joinResult.agoraChannelName, 'chan-source');
      expect(result.relay!.channel.language, 'EN');
    });
  });
}
