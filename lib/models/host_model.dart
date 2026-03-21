enum AuthType { password, privateKey }

extension AuthTypeX on AuthType {
  String get storageValue {
    switch (this) {
      case AuthType.password:
        return 'password';
      case AuthType.privateKey:
        return 'private_key';
    }
  }

  String get label {
    switch (this) {
      case AuthType.password:
        return 'Password';
      case AuthType.privateKey:
        return 'Private Key';
    }
  }

  static AuthType fromStorageValue(String? value) {
    switch (value) {
      case 'private_key':
      case 'privateKey':
        return AuthType.privateKey;
      case 'password':
      default:
        return AuthType.password;
    }
  }
}

class HostModel {
  final String id;
  final String? name;
  final String host;
  final int port;
  final String username;
  final AuthType authType;

  const HostModel({
    required this.id,
    this.name,
    required this.host,
    this.port = 22,
    required this.username,
    required this.authType,
  });

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name! : host;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': displayName,
      'host': host,
      'port': port,
      'username': username,
      'auth_type': authType.storageValue,
    };
  }

  factory HostModel.fromJson(Map<String, dynamic> json) {
    return HostModel(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString(),
      host: (json['host'] ?? '').toString(),
      port: json['port'] is int
          ? json['port'] as int
          : int.tryParse('${json['port'] ?? 22}') ?? 22,
      username: (json['username'] ?? '').toString(),
      authType: AuthTypeX.fromStorageValue(json['auth_type']?.toString()),
    );
  }

  HostModel copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    AuthType? authType,
  }) {
    return HostModel(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
    );
  }
}
