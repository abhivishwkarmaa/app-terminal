import 'package:flutter/foundation.dart';

import '../models/host_model.dart';
import '../models/host_secret_model.dart';
import '../providers/auth_provider.dart';
import '../providers/app_mode_provider.dart';
import '../services/sync_service.dart';
import '../services/storage_service.dart';

class HostProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService();
  final StorageService _storageService = StorageService();
  List<HostModel> _hosts = [];
  AuthProvider? _authProvider;
  AppModeProvider? _appModeProvider;
  bool _isLoading = false;

  List<HostModel> get hosts => _hosts;
  bool get isLoading => _isLoading;

  void updateDependencies(
    AuthProvider authProvider,
    AppModeProvider appModeProvider,
  ) {
    final previousToken = _authProvider?.token;
    final nextToken = authProvider.token;
    final previousMode = _appModeProvider?.mode;
    final nextMode = appModeProvider.mode;
    _authProvider = authProvider;
    _appModeProvider = appModeProvider;

    if (previousToken == nextToken && previousMode == nextMode) return;

    if (nextMode == null) {
      _hosts = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (nextMode == AppMode.offline) {
      Future.microtask(() => loadHosts());
      return;
    }

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

      if (_appModeProvider?.isOfflineMode ?? false) {
        return;
      }

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

    if (_appModeProvider?.isSyncMode ?? false) {
      final token = await _authProvider?.getValidToken();
      if (token != null) {
        await _syncHostToBackend(token, host);
      }
    }

    _hosts = await _storageService.loadHosts();
    notifyListeners();
  }

  Future<void> updateHost(HostModel host, {HostSecretModel? secrets}) async {
    await _storageService.upsertHost(host);
    if (secrets != null) {
      await _storageService.saveSecrets(host.id, secrets);
    }

    if (_appModeProvider?.isSyncMode ?? false) {
      final token = await _authProvider?.getValidToken();
      if (token != null) {
        await _syncHostToBackend(token, host);
      }
    }

    _hosts = await _storageService.loadHosts();
    notifyListeners();
  }

  Future<void> deleteHost(String id) async {
    await _storageService.removeHost(id);
    await _storageService.deleteSecrets(id);

    if (_appModeProvider?.isSyncMode ?? false) {
      final token = await _authProvider?.getValidToken();
      if (token != null) {
        await _syncService.deleteTerminal(token, id);
      }
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
