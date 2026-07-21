class Channel {
  const Channel({
    required this.id,
    required this.sessionId,
    required this.language,
    required this.interpreterCode,
    required this.isSource,
  });

  final int id;
  final int sessionId;
  final String language;
  final String? interpreterCode;
  final bool isSource;

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id'] as int,
        sessionId: json['session'] as int,
        language: json['language'] as String,
        interpreterCode: json['interpreter_code'] as String?,
        isSource: json['is_source'] as bool,
      );
}
