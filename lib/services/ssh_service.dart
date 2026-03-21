import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:xterm/xterm.dart';

enum SSHStatus { disconnected, connecting, connected, error }

class SSHService extends ChangeNotifier {
  SSHClient? _client;
  SSHSession? _session;
  SSHStatus _status = SSHStatus.disconnected;
  String _error = '';
  
  final Terminal terminal = Terminal(
    maxLines: 10000,
  );

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
    required String password,
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

      final socket = await SSHSocket.connect(host, port, timeout: const Duration(seconds: 10));

      _client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
        keepAliveInterval: const Duration(seconds: 5), // Keep connection alive as long as possible
      );

      // Start the shell
      _session = await _client!.shell(
        pty: SSHPtyConfig(width: terminal.viewWidth, height: terminal.viewHeight),
      );
      _status = SSHStatus.connected;
      notifyListeners();

      // Listen to stdout
      _session!.stdout.listen((data) {
        terminal.write(utf8.decode(data));
      }, onError: (e) {
        _error = 'Stdout error: $e';
        notifyListeners();
      }, onDone: () {
        disconnect();
      });

      // Listen to stderr
      _session!.stderr.listen((data) {
        terminal.write(utf8.decode(data));
      });

    } catch (e) {
      _status = SSHStatus.error;
      _error = e.toString();
      terminal.write('\r\nError: $_error\r\n');
      notifyListeners();
    }
  }

  Future<bool> testConnection({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    try {
      final socket = await SSHSocket.connect(host, port, timeout: const Duration(seconds: 10));
      final client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );
      
      // Complete authentication
      await client.authenticated;
      client.close();
      return true;
    } catch (e) {
      debugPrint('SSH Test Connection Failed: $e');
      return false;
    }
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
