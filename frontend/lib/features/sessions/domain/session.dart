import 'channel.dart';

/// Mirrors the backend's Session status state machine exactly (see
/// apps/sessions/models.py) - not_started -> active <-> qa_mode ->
/// ended, ended terminal. This app only exposes start/stop/end
/// controls (see ADR-007 / the guide-ui slice scope); qa_mode is a
/// state the backend can be in but this UI doesn't yet have a control
/// to enter, since the Q&A guide screen is a later slice.
enum SessionStatus { notStarted, active, qaMode, ended }

SessionStatus _statusFromJson(String value) {
  switch (value) {
    case 'not_started':
      return SessionStatus.notStarted;
    case 'active':
      return SessionStatus.active;
    case 'qa_mode':
      return SessionStatus.qaMode;
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
    required this.sourceLanguage,
    required this.listenerCode,
    required this.status,
    required this.createdAt,
    required this.channels,
  });

  final int id;
  final String name;
  final String sourceLanguage;
  final String listenerCode;
  final SessionStatus status;
  final DateTime createdAt;
  final List<Channel> channels;

  /// Whether Start (not_started -> active) is a legal next step.
  bool get canStart => status == SessionStatus.notStarted;

  /// Whether Stop (-> not_started) is a legal next step.
  bool get canStop =>
      status == SessionStatus.active || status == SessionStatus.qaMode;

  /// Whether End (-> ended, terminal) is a legal next step.
  bool get canEnd => status != SessionStatus.ended;

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as int,
        name: json['name'] as String,
        sourceLanguage: json['source_language'] as String,
        listenerCode: json['listener_code'] as String,
        status: _statusFromJson(json['status'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        channels: (json['channels'] as List<dynamic>)
            .map((entry) => Channel.fromJson(entry as Map<String, dynamic>))
            .toList(),
      );
}
