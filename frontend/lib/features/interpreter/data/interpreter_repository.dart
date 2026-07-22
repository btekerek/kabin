import 'package:dio/dio.dart';

import '../../../core/agora/agora_join_result.dart';
import '../../listener/domain/listener_channel.dart';
import '../../sessions/domain/channel.dart';
import '../domain/interpreter_join_result.dart';

/// Authenticated (Interpreter role) counterpart to ListenerRepository -
/// wraps ChannelJoinView/ChannelLeaveView/ChannelRelayView/
/// ChannelSwitchView. Unlike the listener flow, there's no separate
/// lookup step: the interpreter code alone identifies the channel to
/// claim.
class InterpreterRepository {
  InterpreterRepository(this._dio);

  final Dio _dio;

  Future<InterpreterJoinResult> join(String interpreterCode) async {
    final response = await _dio.post('/api/channels/join/', data: {
      'interpreter_code': interpreterCode,
    });
    return _parseClaimPayload(response.data as Map<String, dynamic>);
  }

  /// A no-op server-side if the caller doesn't hold the channel - safe
  /// to call defensively (e.g. from a screen's dispose) without first
  /// checking whether the claim is actually ours.
  Future<void> leave(String interpreterCode) async {
    await _dio.post('/api/channels/leave/', data: {
      'interpreter_code': interpreterCode,
    });
  }

  /// Switches which channel this interpreter relays from - [channelId]
  /// is their own claimed channel, [relayChannelId] the channel they now
  /// want to listen to while interpreting.
  Future<RelayJoinResult> setRelay({
    required int channelId,
    required int relayChannelId,
  }) async {
    final response = await _dio.post('/api/channels/$channelId/relay/', data: {
      'relay_channel_id': relayChannelId,
    });
    return RelayJoinResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Moves this interpreter's claim from [channelId] to
  /// [targetChannelId] - their "target language" dropdown. Returns a
  /// fresh full claim payload (new publish token, reset relay default,
  /// etc.) exactly like [join] does, since it's effectively a new claim.
  Future<InterpreterJoinResult> switchChannel({
    required int channelId,
    required int targetChannelId,
  }) async {
    final response = await _dio.post('/api/channels/$channelId/switch/', data: {
      'target_channel_id': targetChannelId,
    });
    return _parseClaimPayload(response.data as Map<String, dynamic>);
  }

  InterpreterJoinResult _parseClaimPayload(Map<String, dynamic> data) {
    final relay = data['relay'] as Map<String, dynamic>?;
    final availableRelayChannels = data['available_relay_channels'] as List;
    final availableTargetChannels = data['available_target_channels'] as List;
    return InterpreterJoinResult(
      joinResult: AgoraJoinResult.fromJson(data),
      channel: Channel.fromJson(data['channel'] as Map<String, dynamic>),
      relay: relay == null ? null : RelayJoinResult.fromJson(relay),
      availableRelayChannels: availableRelayChannels
          .map((json) => ListenerChannel.fromJson(json as Map<String, dynamic>))
          .toList(),
      availableTargetChannels: availableTargetChannels
          .map((json) => ListenerChannel.fromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }
}
