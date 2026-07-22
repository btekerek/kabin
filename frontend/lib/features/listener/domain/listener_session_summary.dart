import '../../sessions/domain/session.dart'
    show SessionStatus, sessionStatusFromJson;
import 'listener_channel.dart';

/// What a PIN lookup returns to an anonymous listener
/// (SessionLookupSerializer) - deliberately narrower than the
/// Guide-facing Session: no listener_code (they already have it - it's
/// what they typed in), no source_language, no created_at.
class ListenerSessionSummary {
  const ListenerSessionSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.channels,
  });

  final int id;
  final String name;
  final SessionStatus status;
  final List<ListenerChannel> channels;

  factory ListenerSessionSummary.fromJson(Map<String, dynamic> json) =>
      ListenerSessionSummary(
        id: json['id'] as int,
        name: json['name'] as String,
        status: sessionStatusFromJson(json['status'] as String),
        channels: (json['channels'] as List<dynamic>)
            .map((entry) =>
                ListenerChannel.fromJson(entry as Map<String, dynamic>))
            .toList(),
      );
}
