import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:xterm/xterm.dart';

import '../models/host_model.dart';

enum SSHStatus { disconnected, connecting, connected, error }

enum SSHPrivateKeyType { rsa, opensshEd25519, unknown }

class SSHValidationResult {
  final bool isValid;
  final String? message;

  const SSHValidationResult._(this.isValid, this.message);

  const SSHValidationResult.success() : this._(true, null);

  const SSHValidationResult.failure(String message) : this._(false, message);
}

class SSHService extends ChangeNotifier {
  SSHClient? _client;
  SSHSession? _session;
  SSHStatus _status = SSHStatus.disconnected;
  String _error = '';

  final Terminal terminal = Terminal(maxLines: 10000);

  SSHStatus get status => _status;
  String get error => _error;

  SSHService() {
    // Listen to terminal output (typing)
    terminal.onOutput = (data) {
      if (_session != null && _status == SSHStatus.connected) {
        _session!.stdin.add(utf8.encode(data));
      }
    };
  }

  Future<void> connect({
    required String host,
    required int port,
    required String username,
    required AuthType authType,
    String? password,
    String? privateKey,
    String? passphrase,
  }) async {
    _status = SSHStatus.connecting;
    _error = '';
    terminal.write('\r\nConnecting to $host:$port...\r\n');
    notifyListeners();

    try {
      // Ensure we can run in the background
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          final androidConfig = FlutterBackgroundAndroidConfig(
            notificationTitle: "Terminal is active",
            notificationText: "Running SSH Session in background",
            notificationImportance: AndroidNotificationImportance.normal,
            enableWifiLock: true,
          );
          await FlutterBackground.initialize(androidConfig: androidConfig);
          await FlutterBackground.enableBackgroundExecution();
        } catch (_) {
          // Ignore if background task is already enabled or unsupported on current platform (iOS limitation)
        }
      }

      final socket = await SSHSocket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
      );
      _client = _buildClient(
        socket: socket,
        username: username,
        authType: authType,
        password: password,
        privateKey: privateKey,
        passphrase: passphrase,
        keepAliveInterval: const Duration(seconds: 5),
      );
      await _client!.authenticated;

      // Start the shell
      _session = await _client!.shell(
        pty: SSHPtyConfig(
          width: terminal.viewWidth,
          height: terminal.viewHeight,
        ),
      );
      _status = SSHStatus.connected;
      notifyListeners();

      // Listen to stdout
      _session!.stdout.listen(
        (data) {
          terminal.write(utf8.decode(data));
        },
        onError: (e) {
          _error = 'Stdout error: $e';
          notifyListeners();
        },
        onDone: () {
          disconnect();
        },
      );

      // Listen to stderr
      _session!.stderr.listen((data) {
        terminal.write(utf8.decode(data));
      });
    } catch (e) {
      _status = SSHStatus.error;
      _error = _friendlyError(e, authType);
      terminal.write('\r\nError: $_error\r\n');
      notifyListeners();
    }
  }

  Future<SSHValidationResult> testConnection({
    required String host,
    required int port,
    required String username,
    required AuthType authType,
    String? password,
    String? privateKey,
    String? passphrase,
  }) async {
    try {
      final socket = await SSHSocket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
      );
      final client = _buildClient(
        socket: socket,
        username: username,
        authType: authType,
        password: password,
        privateKey: privateKey,
        passphrase: passphrase,
      );
      final session = await client.execute('whoami');
      await utf8.decoder.bind(session.stdout).join();
      client.close();
      return const SSHValidationResult.success();
    } catch (e) {
      debugPrint('SSH test connection failed: ${_friendlyError(e, authType)}');
      return SSHValidationResult.failure(_friendlyError(e, authType));
    }
  }

  String? validatePrivateKey({
    required String privateKey,
    String? passphrase,
    bool requirePassphraseIfEncrypted = false,
  }) {
    try {
      final parsedKey = _parsePrivateKey(
        privateKey: privateKey,
        passphrase: passphrase,
        requirePassphraseIfEncrypted: requirePassphraseIfEncrypted,
      );
      final isEncrypted = SSHKeyPair.isEncryptedPem(parsedKey.cleanedKey);
      if (isEncrypted &&
          requirePassphraseIfEncrypted &&
          (passphrase == null || passphrase.isEmpty)) {
        return 'This private key is encrypted. Enter its passphrase.';
      }
      return null;
    } catch (error) {
      return _friendlyPrivateKeyError(error);
    }
  }

  SSHClient _buildClient({
    required SSHSocket socket,
    required String username,
    required AuthType authType,
    String? password,
    String? privateKey,
    String? passphrase,
    Duration? keepAliveInterval,
  }) {
    switch (authType) {
      case AuthType.password:
        final normalizedPassword = _normalizeSecret(password);
        if (normalizedPassword == null) {
          throw ArgumentError('Password is required.');
        }
        return SSHClient(
          socket,
          username: username,
          onPasswordRequest: () => normalizedPassword,
          keepAliveInterval: keepAliveInterval,
        );
      case AuthType.privateKey:
        final parsedKey = _parsePrivateKey(
          privateKey: privateKey,
          passphrase: passphrase,
          requirePassphraseIfEncrypted: false,
        );
        return SSHClient(
          socket,
          username: username,
          identities: parsedKey.rsaKeyPair != null
              ? [parsedKey.rsaKeyPair!]
              : parsedKey.identities,
          keepAliveInterval: keepAliveInterval,
        );
    }
  }

  String _friendlyError(Object error, AuthType authType) {
    if (error is TimeoutException) {
      return 'Connection timed out. Verify the host, port, and network reachability.';
    }
    if (error is SocketException || error is SSHSocketError) {
      return 'Unable to reach the SSH server. Check the host, port, and network.';
    }
    if (error is SSHAuthFailError || error is SSHAuthAbortError) {
      return authType == AuthType.password
          ? 'Authentication failed. Check the username and password.'
          : 'SSH authentication failed. Ensure the RSA key matches the server, the public key is in authorized_keys, and try the correct username such as ubuntu, ec2-user, or admin.';
    }
    if (error is SSHKeyDecryptError) {
      return 'The private key passphrase is incorrect.';
    }
    if (error is SSHKeyDecodeError || error is FormatException) {
      return _friendlyPrivateKeyError(error);
    }
    if (error is UnsupportedError) {
      return _friendlyPrivateKeyError(error);
    }
    if (error is ArgumentError) {
      final message = error.message.toString();
      if (message.contains('passphrase is required')) {
        return 'This private key is encrypted. Enter its passphrase.';
      }
      if (message.contains('Private key is required')) {
        return 'Private key is required.';
      }
      if (message.contains('must include BEGIN and END lines')) {
        return 'Invalid private key format. The key must include BEGIN and END lines.';
      }
      if (message.contains('Password is required')) {
        return 'Password is required.';
      }
      if (message.contains('unsupported ed25519')) {
        return 'ED25519 keys may not be supported. Please use RSA key. For best compatibility, use RSA private key (PEM format).';
      }
      if (message.contains('Invalid RSA private key format')) {
        return 'Invalid RSA private key format.';
      }
      if (message.contains('Invalid private key')) {
        return 'Invalid private key or unsupported format (ed25519 may not be supported). For best compatibility, use RSA private key (PEM format).';
      }
    }
    return 'SSH connection failed. Please verify the connection details and try again.';
  }

  _ParsedPrivateKey _parsePrivateKey({
    required String? privateKey,
    String? passphrase,
    required bool requirePassphraseIfEncrypted,
  }) {
    final cleanedKey = privateKey?.trim() ?? '';
    if (cleanedKey.isEmpty) {
      throw ArgumentError('Private key is required.');
    }

    final keyType = _detectPrivateKeyType(cleanedKey);
    _validatePemBoundaries(cleanedKey, keyType);
    _logKeyDiagnostics(cleanedKey);

    try {
      if (keyType == SSHPrivateKeyType.rsa) {
        final rsaKeyPair = SSHKeyPair.fromPem(
          cleanedKey,
          _normalizeSecret(passphrase),
        ).single;
        return _ParsedPrivateKey(
          cleanedKey: cleanedKey,
          keyType: keyType,
          identities: [rsaKeyPair],
          rsaKeyPair: rsaKeyPair,
        );
      }

      final identities = SSHKeyPair.fromPem(
        cleanedKey,
        _normalizeSecret(passphrase),
      );
      return _ParsedPrivateKey(
        cleanedKey: cleanedKey,
        keyType: keyType,
        identities: identities,
      );
    } on SSHKeyDecryptError {
      rethrow;
    } on ArgumentError catch (error) {
      if (error.message.toString().contains('passphrase is required') &&
          requirePassphraseIfEncrypted) {
        rethrow;
      }
      if (keyType == SSHPrivateKeyType.opensshEd25519) {
        throw ArgumentError('unsupported ed25519');
      }
      throw ArgumentError('Private key parsing failed: $error');
    } on UnsupportedError {
      if (keyType == SSHPrivateKeyType.opensshEd25519) {
        throw ArgumentError('unsupported ed25519');
      }
      rethrow;
    } on FormatException {
      if (keyType == SSHPrivateKeyType.opensshEd25519) {
        throw ArgumentError('unsupported ed25519');
      }
      rethrow;
    } on SSHKeyDecodeError {
      if (keyType == SSHPrivateKeyType.opensshEd25519) {
        throw ArgumentError('unsupported ed25519');
      }
      rethrow;
    }
  }

  void _validatePemBoundaries(String cleanedKey, SSHPrivateKeyType keyType) {
    final lines = cleanedKey
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty ||
        !lines.first.startsWith('-----BEGIN ') ||
        !lines.last.startsWith('-----END ')) {
      throw ArgumentError('Private key must include BEGIN and END lines.');
    }

    if (keyType == SSHPrivateKeyType.rsa &&
        !cleanedKey.contains('BEGIN RSA PRIVATE KEY')) {
      throw ArgumentError('Invalid RSA private key format');
    }
  }

  void _logKeyDiagnostics(String cleanedKey) {
    final lines = cleanedKey.split('\n');
    if (lines.isEmpty) return;

    debugPrint('SSH private key length: ${cleanedKey.length}');
    debugPrint('SSH private key first line: ${lines.first}');
    debugPrint('SSH private key last line: ${lines.last}');
  }

  SSHPrivateKeyType _detectPrivateKeyType(String cleanedKey) {
    if (cleanedKey.contains('BEGIN RSA PRIVATE KEY')) {
      return SSHPrivateKeyType.rsa;
    }
    if (cleanedKey.contains('BEGIN OPENSSH PRIVATE KEY')) {
      return SSHPrivateKeyType.opensshEd25519;
    }
    return SSHPrivateKeyType.unknown;
  }

  String _friendlyPrivateKeyError(Object error) {
    if (error is SSHKeyDecryptError) {
      return 'The private key passphrase is incorrect.';
    }
    if (error is ArgumentError) {
      final message = error.message.toString();
      if (message.contains('passphrase is required')) {
        return 'This private key is encrypted. Enter its passphrase.';
      }
      if (message.contains('must include BEGIN and END lines')) {
        return 'Invalid private key format. The key must include BEGIN and END lines.';
      }
      if (message.contains('unsupported ed25519')) {
        return 'ED25519 keys may not be supported. Please use RSA key. For best compatibility, use RSA private key (PEM format).';
      }
      if (message.contains('Invalid RSA private key format')) {
        return 'Invalid RSA private key format.';
      }
      if (message.contains('Private key parsing failed')) {
        return 'Invalid private key or unsupported format. Ensure RSA key is PEM format.';
      }
    }
    if (error is UnsupportedError ||
        error is SSHKeyDecodeError ||
        error is FormatException) {
      return 'Invalid private key or unsupported format (ed25519 may not be supported). For best compatibility, use RSA private key (PEM format).';
    }
    return 'Invalid private key or unsupported format (ed25519 may not be supported). For best compatibility, use RSA private key (PEM format).';
  }

  String? _normalizeSecret(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  void writeToStdin(String data) {
    if (_session != null && _status == SSHStatus.connected) {
      _session!.stdin.add(utf8.encode(data));
    }
  }

  void resize(int width, int height) {
    if (_session != null && _status == SSHStatus.connected) {
      _session!.resizeTerminal(width, height);
    }
  }

  void disconnect() {
    _session?.close();
    _client?.close();
    _session = null;
    _client = null;
    _status = SSHStatus.disconnected;
    terminal.write('\r\nDisconnected.\r\n');
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        FlutterBackground.disableBackgroundExecution();
      }
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

class _ParsedPrivateKey {
  final String cleanedKey;
  final SSHPrivateKeyType keyType;
  final List<SSHKeyPair> identities;
  final SSHKeyPair? rsaKeyPair;

  const _ParsedPrivateKey({
    required this.cleanedKey,
    required this.keyType,
    required this.identities,
    this.rsaKeyPair,
  });
}
