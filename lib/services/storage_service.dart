import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/host_model.dart';
import '../models/host_secret_model.dart';

class StorageService {
  static const String _hostListKey = 'host_list';
  static const String _passwordSuffix = 'password';
  static const String _privateKeySuffix = 'privateKey';
  static const String _passphraseSuffix = 'passphrase';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String _storageKey(String hostId, String suffix) => '${hostId}_$suffix';

  Future<List<HostModel>> loadHosts() async {
    final prefs = await SharedPreferences.getInstance();
    final hostsJson = prefs.getString(_hostListKey);
    if (hostsJson == null || hostsJson.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(hostsJson) as List<dynamic>;
    return decoded
        .map((item) => HostModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveHosts(List<HostModel> hosts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(hosts.map((host) => host.toJson()).toList());
    await prefs.setString(_hostListKey, encoded);
  }

  Future<void> upsertHost(HostModel host) async {
    final hosts = await loadHosts();
    final index = hosts.indexWhere((item) => item.id == host.id);
    if (index == -1) {
      hosts.add(host);
    } else {
      hosts[index] = host;
    }
    await saveHosts(hosts);
  }

  Future<void> removeHost(String hostId) async {
    final hosts = await loadHosts();
    hosts.removeWhere((host) => host.id == hostId);
    await saveHosts(hosts);
  }

  Future<void> saveSecrets(String hostId, HostSecretModel secrets) async {
    await deleteSecrets(hostId);

    if (secrets.authType == AuthType.password) {
      await _secureStorage.write(
        key: _storageKey(hostId, _passwordSuffix),
        value: secrets.password,
      );
      return;
    }

    await _secureStorage.write(
      key: _storageKey(hostId, _privateKeySuffix),
      value: secrets.privateKey,
    );

    if (secrets.normalizedPassphrase != null) {
      await _secureStorage.write(
        key: _storageKey(hostId, _passphraseSuffix),
        value: secrets.normalizedPassphrase,
      );
    }
  }

  Future<HostSecretModel?> getSecrets(HostModel host) async {
    if (host.authType == AuthType.password) {
      final password = await _secureStorage.read(
        key: _storageKey(host.id, _passwordSuffix),
      );
      if (password == null || password.isEmpty) {
        return null;
      }
      return HostSecretModel(authType: AuthType.password, password: password);
    }

    final privateKey = await _secureStorage.read(
      key: _storageKey(host.id, _privateKeySuffix),
    );
    if (privateKey == null || privateKey.trim().isEmpty) {
      return null;
    }

    final passphrase = await _secureStorage.read(
      key: _storageKey(host.id, _passphraseSuffix),
    );

    return HostSecretModel(
      authType: AuthType.privateKey,
      privateKey: privateKey,
      passphrase: passphrase,
    );
  }

  Future<void> deleteSecrets(String hostId) async {
    await _secureStorage.delete(key: _storageKey(hostId, _passwordSuffix));
    await _secureStorage.delete(key: _storageKey(hostId, _privateKeySuffix));
    await _secureStorage.delete(key: _storageKey(hostId, _passphraseSuffix));
  }
}
