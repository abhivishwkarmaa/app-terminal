class BackendConfig {
  // Keep auth and host sync pinned to the same backend instance.
  static String get host => '192.142.3.54';

  static String get baseUrl => 'http://$host:8080';
  static String get apiBaseUrl => '$baseUrl/api';
}
