class BackendConfig {
  // Single switch: true = VPS, false = local.
  static const bool useVpsServer = true;

  static const String _localHost = '127.0.0.1';
  static const int _localPort = 8080;
  static const String _vpsHost = '192.142.3.54';
  static const int _vpsPort = 8080;

  static const String _hostOverride = String.fromEnvironment('BACKEND_HOST');
  static const String _portOverride = String.fromEnvironment('BACKEND_PORT');
  static const String _schemeOverride = String.fromEnvironment(
    'BACKEND_SCHEME',
    defaultValue: 'http',
  );

  static String get host {
    if (_hostOverride.isNotEmpty) return _hostOverride;
    return useVpsServer ? _vpsHost : _localHost;
  }

  static String get scheme => _schemeOverride;

  static int get port =>
      int.tryParse(_portOverride) ?? (useVpsServer ? _vpsPort : _localPort);

  static String get baseUrl => '$scheme://$host:$port';
  static String get apiBaseUrl => '$baseUrl/api';
}
