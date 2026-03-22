import 'package:flutter/foundation.dart';

import '../models/host_model.dart';
import '../models/host_secret_model.dart';
import '../services/sync_service.dart';
import '../services/storage_service.dart';
import 'auth_provider.dart';

class HostProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService();
  final StorageService _storageService = StorageService();
  List<HostModel> _hosts = [];
  AuthProvider? _authProvider;
  bool _isLoading = false;

  List<HostModel> get hosts => _hosts;
  bool get isLoading => _isLoading;

  void updateAuth(AuthProvider authProvider) {
    final previousToken = _authProvider?.token;
    final nextToken = authProvider.token;
    _authProvider = authProvider;

    if (previousToken == nextToken) return;

    if (nextToken != null) {
      Future.microtask(() => loadHosts());
    } else {
      _hosts = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHosts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final localHosts = await _storageService.loadHosts();
      _hosts = localHosts;

      final token = await _authProvider?.getValidToken();
      if (token == null) {
        return;
      }

      await _syncLocalHostsToBackend(token, localHosts);
      final cloudHosts = await _syncService.fetchTerminals(token);
      if (cloudHosts.isNotEmpty) {
        _hosts = cloudHosts;
        await _storageService.saveHosts(cloudHosts);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addHost(HostModel host, HostSecretModel secrets) async {
    await _storageService.upsertHost(host);
    await _storageService.saveSecrets(host.id, secrets);

    final token = await _authProvider?.getValidToken();
    if (token != null) {
      await _syncHostToBackend(token, host);
    }

    _hosts = await _storageService.loadHosts();
    notifyListeners();
  }

  Future<void> updateHost(HostModel host, {HostSecretModel? secrets}) async {
    await _storageService.upsertHost(host);
    if (secrets != null) {
      await _storageService.saveSecrets(host.id, secrets);
    }

    final token = await _authProvider?.getValidToken();
    if (token != null) {
      await _syncHostToBackend(token, host);
    }

    _hosts = await _storageService.loadHosts();
    notifyListeners();
  }

  Future<void> deleteHost(String id) async {
    await _storageService.removeHost(id);
    await _storageService.deleteSecrets(id);

    final token = await _authProvider?.getValidToken();
    if (token != null) {
      await _syncService.deleteTerminal(token, id);
    }

    _hosts = await _storageService.loadHosts();
    notifyListeners();
  }

  Future<HostSecretModel?> getSecrets(HostModel host) async {
    return _storageService.getSecrets(host);
  }

  Future<void> saveSecrets(HostModel host, HostSecretModel secrets) async {
    await _storageService.saveSecrets(host.id, secrets);
  }

  Future<void> _syncLocalHostsToBackend(
    String token,
    List<HostModel> localHosts,
  ) async {
    for (final host in localHosts) {
      await _syncHostToBackend(token, host);
    }
  }

  Future<void> _syncHostToBackend(String token, HostModel host) async {
    final updated = await _syncService.updateTerminal(token, host);
    if (updated) {
      return;
    }

    await _syncService.createTerminal(token, host);
  }
}
