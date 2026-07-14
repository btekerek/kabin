/// A single language channel within a session. `interpreterCode` is only
/// ever present for the Guide's own view (ChannelSerializer) - the
/// listener-facing shape omits it, but this app has no listener screens
/// yet so there's only one shape to model.
class Channel {
  const Channel({
    required this.id,
    required this.language,
    required this.interpreterCode,
    required this.isSource,
  });

  final int id;
  final String language;
  final String interpreterCode;
  final bool isSource;

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id'] as int,
        language: json['language'] as String,
        interpreterCode: json['interpreter_code'] as String,
        isSource: json['is_source'] as bool,
      );
}
