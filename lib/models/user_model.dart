class BackendUser {
  final String id;
  final String email;
  final String? name;
  final String googleId;
  final String? pictureUrl;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name! : email;

  BackendUser({
    required this.id,
    required this.email,
    this.name,
    required this.googleId,
    this.pictureUrl,
  });

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    final rawName = json['name']?.toString();
    final pic = json['picture_url']?.toString();
    return BackendUser(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: (rawName != null && rawName.trim().isNotEmpty) ? rawName : null,
      googleId: (json['google_id'] ?? '').toString(),
      pictureUrl: (pic != null && pic.trim().isNotEmpty) ? pic : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'google_id': googleId,
      'picture_url': pictureUrl,
    };
  }
}
