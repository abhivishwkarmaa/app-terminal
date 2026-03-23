enum AuthType { password, privateKey }

enum ConnectionType { ssh, mysql }

extension ConnectionTypeX on ConnectionType {
  String get storageValue {
    switch (this) {
      case ConnectionType.ssh:
        return 'ssh';
      case ConnectionType.mysql:
        return 'mysql';
    }
  }

  String get label {
    switch (this) {
      case ConnectionType.ssh:
        return 'SSH';
      case ConnectionType.mysql:
        return 'MySQL';
    }
  }

  static ConnectionType fromStorageValue(String? value) {
    switch (value) {
      case 'mysql':
        return ConnectionType.mysql;
      case 'ssh':
      default:
        return ConnectionType.ssh;
    }
  }
}

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
  final ConnectionType connectionType;
  final String host;
  final int port;
  final String username;
  final AuthType authType;
  final String? databaseName;

  const HostModel({
    required this.id,
    this.name,
    this.connectionType = ConnectionType.ssh,
    required this.host,
    this.port = 22,
    required this.username,
    required this.authType,
    this.databaseName,
  });

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name! : host;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': displayName,
      'connection_type': connectionType.storageValue,
      'host': host,
      'port': port,
      'username': username,
      'auth_type': authType.storageValue,
      'database_name': databaseName,
    };
  }

  factory HostModel.fromJson(Map<String, dynamic> json) {
    return HostModel(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString(),
      connectionType: ConnectionTypeX.fromStorageValue(
        json['connection_type']?.toString(),
      ),
      host: (json['host'] ?? '').toString(),
      port: json['port'] is int
          ? json['port'] as int
          : int.tryParse('${json['port'] ?? 22}') ?? 22,
      username: (json['username'] ?? '').toString(),
      authType: AuthTypeX.fromStorageValue(json['auth_type']?.toString()),
      databaseName: json['database_name']?.toString(),
    );
  }

  HostModel copyWith({
    String? name,
    ConnectionType? connectionType,
    String? host,
    int? port,
    String? username,
    AuthType? authType,
    String? databaseName,
  }) {
    return HostModel(
      id: id,
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      databaseName: databaseName ?? this.databaseName,
    );
  }
}
