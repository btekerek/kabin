/// The current account, as returned by /api/auth/me/ and
/// /api/auth/register/. There's no fixed account role - any logged in
/// user can create a session (becoming its owner) or claim an
/// interpreter channel (see HomeScreen). Listeners have no account and
/// never produce a [User].
class User {
  const User({required this.id, required this.email});

  final int id;
  final String email;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        email: json['email'] as String,
      );
}
