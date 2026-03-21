class HostModel {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String? encryptedBlob;

  HostModel({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.encryptedBlob,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      if (encryptedBlob != null) 'encrypted_blob': encryptedBlob,
    };
  }

  factory HostModel.fromJson(Map<String, dynamic> json) {
    return HostModel(
      id: json['id'],
      name: json['name'],
      host: json['host'],
      port: json['port'] ?? 22,
      username: json['username'],
      encryptedBlob: json['encrypted_blob'],
    );
  }

  HostModel copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    String? encryptedBlob,
  }) {
    return HostModel(
      id: this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      encryptedBlob: encryptedBlob ?? this.encryptedBlob,
    );
  }
}
