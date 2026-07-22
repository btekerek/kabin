import 'channel.dart';

/// Mirrors the backend's Session status state machine exactly (see
/// apps/sessions/models.py) - not_started -> active -> ended, ended
/// terminal. Q&A (raise hand / floor / speak) is not implemented yet,
/// so there's no qa_mode state to mirror here.
enum SessionStatus { notStarted, active, ended }

SessionStatus sessionStatusFromJson(String value) {
  switch (value) {
    case 'not_started':
      return SessionStatus.notStarted;
    case 'active':
      return SessionStatus.active;
    case 'ended':
      return SessionStatus.ended;
    default:
      throw ArgumentError('Unknown session status: $value');
  }
}

class Session {
  const Session({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceLanguage,
    required this.listenerCode,
    required this.status,
    required this.createdAt,
    required this.channels,
  });

  final int id;
  final String name;
  final String description;
  final String sourceLanguage;
  final String listenerCode;
  final SessionStatus status;
  final DateTime createdAt;
  final List<Channel> channels;

  /// Whether Start (not_started -> active) is a legal next step.
  bool get canStart => status == SessionStatus.notStarted;

  /// Whether Stop (-> not_started) is a legal next step.
  bool get canStop => status == SessionStatus.active;

  /// Whether End (-> ended, terminal) is a legal next step.
  bool get canEnd => status != SessionStatus.ended;

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        sourceLanguage: json['source_language'] as String,
        listenerCode: json['listener_code'] as String,
        status: sessionStatusFromJson(json['status'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        channels: (json['channels'] as List<dynamic>)
            .map((entry) => Channel.fromJson(entry as Map<String, dynamic>))
            .toList(),
      );
}
