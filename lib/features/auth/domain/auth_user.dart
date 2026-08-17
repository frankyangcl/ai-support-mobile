class AuthUser {
  const AuthUser({required this.id, this.name, this.email, this.pictureUrl});

  final String id;
  final String? name;
  final String? email;
  final Uri? pictureUrl;

  String get displayName => name ?? email ?? 'Signed-in user';
}
