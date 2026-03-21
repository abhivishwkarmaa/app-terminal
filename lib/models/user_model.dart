class BackendUser {
  final String id;
  final String email;
  final String name;
  final String googleId;
  final String? pictureUrl;

  BackendUser({
    required this.id,
    required this.email,
    required this.name,
    required this.googleId,
    this.pictureUrl,
  });

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    final pic = json['picture_url']?.toString();
    return BackendUser(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      googleId: (json['google_id'] ?? '').toString(),
      pictureUrl: (pic != null && pic.trim().isNotEmpty) ? pic : null,
    );
  }
}
