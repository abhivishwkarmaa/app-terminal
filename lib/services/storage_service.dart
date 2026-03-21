import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/host_model.dart';

class StorageService {
  static const String _hostListKey = 'host_list';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<List<HostModel>> loadHosts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? hostsJson = prefs.getString(_hostListKey);
    if (hostsJson == null) return [];
    
    final List<dynamic> decoded = jsonDecode(hostsJson);
    return decoded.map((item) => HostModel.fromJson(item)).toList();
  }

  Future<void> saveHosts(List<HostModel> hosts) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(hosts.map((h) => h.toJson()).toList());
    await prefs.setString(_hostListKey, encoded);
  }

  Future<void> savePassword(String hostId, String password) async {
    await _secureStorage.write(key: 'password_$hostId', value: password);
  }

  Future<String?> getPassword(String hostId) async {
    return await _secureStorage.read(key: 'password_$hostId');
  }

  Future<void> deletePassword(String hostId) async {
    await _secureStorage.delete(key: 'password_$hostId');
  }

  Future<void> addHost(HostModel host, String password) async {
    final hosts = await loadHosts();
    hosts.add(host);
    await saveHosts(hosts);
    await savePassword(host.id, password);
  }

  Future<void> updateHost(HostModel updatedHost, String? password) async {
    final hosts = await loadHosts();
    final index = hosts.indexWhere((h) => h.id == updatedHost.id);
    if (index != -1) {
      hosts[index] = updatedHost;
      await saveHosts(hosts);
      if (password != null && password.isNotEmpty) {
        await savePassword(updatedHost.id, password);
      }
    }
  }

  Future<void> deleteHost(String hostId) async {
    final hosts = await loadHosts();
    hosts.removeWhere((h) => h.id == hostId);
    await saveHosts(hosts);
    await deletePassword(hostId);
  }
}
