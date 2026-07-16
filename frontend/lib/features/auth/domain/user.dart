/// The current account, as returned by /api/auth/me/ and
/// /api/auth/register/. `role` is "guide" or "interpreter" - listeners
/// have no account and never produce a [User].
class User {
  const User({required this.id, required this.email, required this.role});

  final int id;
  final String email;
  final String role;

  bool get isGuide => role == 'guide';

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        email: json['email'] as String,
        role: json['role'] as String,
      );
}
