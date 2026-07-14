/// One entry from the backend's language registry (see ADR-006 /
/// GET /api/languages/) - the same list the backend validates
/// source_language/target_languages against at session creation, so
/// anything picked here is guaranteed to be accepted.
class Language {
  const Language({required this.code, required this.name});

  final String code;
  final String name;

  factory Language.fromJson(Map<String, dynamic> json) => Language(
        code: json['code'] as String,
        name: json['name'] as String,
      );
}
