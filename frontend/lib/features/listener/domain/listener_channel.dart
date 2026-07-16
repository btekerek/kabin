/// A channel as an anonymous listener is allowed to see it
/// (ListenerChannelSerializer) - no interpreter_code, unlike the
/// Guide-facing Channel in features/sessions/domain/channel.dart.
class ListenerChannel {
  const ListenerChannel({
    required this.id,
    required this.language,
    required this.isSource,
  });

  final int id;
  final String language;
  final bool isSource;

  factory ListenerChannel.fromJson(Map<String, dynamic> json) =>
      ListenerChannel(
        id: json['id'] as int,
        language: json['language'] as String,
        isSource: json['is_source'] as bool,
      );
}
