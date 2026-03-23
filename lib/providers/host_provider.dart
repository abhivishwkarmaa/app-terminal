import 'package:flutter/foundation.dart';

import '../models/host_model.dart';
import '../models/host_secret_model.dart';
import '../models/pending_sync_operation.dart';
import '../services/sync_service.dart';
import '../services/storage_service.dart';
import 'auth_provider.dart';

class HostProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService();
  final StorageService _storageService = StorageService();
  List<HostModel> _hosts = [];
  Set<String> _pendingSyncHostIds = <String>{};
  AuthProvider? _authProvider;
  bool _isLoading = false;

  List<HostModel> get hosts => _hosts;
  bool get isLoading => _isLoading;
  int get pendingSyncCount {
    if (_hosts.isEmpty || _pendingSyncHostIds.isEmpty) {
      return 0;
    }
    final visibleHostIds = _hosts.map((host) => host.id).toSet();
    return _pendingSyncHostIds
        .where((hostId) => visibleHostIds.contains(hostId))
        .length;
  }

  bool isPendingSync(String hostId) => _pendingSyncHostIds.contains(hostId);

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
      final localHosts = await _loadAndNormalizeStoredHosts();
      _hosts = localHosts;
      await _refreshPendingSyncState();

      final token = await _authProvider?.getSyncToken();
      if (token == null) {
        return;
      }

      await _flushPendingSyncOperations(token);
      final cloudHosts = await _syncService.fetchTerminals(token);
      if (cloudHosts.isNotEmpty) {
        final mergedHosts = _normalizeHosts(
          _mergeCloudHostsWithLocal(localHosts, cloudHosts),
        );
        _hosts = mergedHosts;
        await _storageService.saveHosts(mergedHosts);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addHost(HostModel host, HostSecretModel secrets) async {
    await _storageService.upsertHost(host);
    await _storageService.saveSecrets(host.id, secrets);
    await _storageService.enqueueUpsert(host);
    await _refreshPendingSyncState();

    final token = await _authProvider?.getSyncToken();
    if (token != null) {
      await _flushPendingSyncOperations(token);
    }

    _hosts = await _loadAndNormalizeStoredHosts();
    notifyListeners();
  }

  Future<void> updateHost(HostModel host, {HostSecretModel? secrets}) async {
    await _storageService.upsertHost(host);
    if (secrets != null) {
      await _storageService.saveSecrets(host.id, secrets);
    }
    await _storageService.enqueueUpsert(host);
    await _refreshPendingSyncState();

    final token = await _authProvider?.getSyncToken();
    if (token != null) {
      await _flushPendingSyncOperations(token);
    }

    _hosts = await _loadAndNormalizeStoredHosts();
    notifyListeners();
  }

  Future<void> deleteHost(String id) async {
    await _storageService.removeHost(id);
    await _storageService.deleteSecrets(id);
    await _storageService.enqueueDelete(id);
    await _refreshPendingSyncState();

    final token = await _authProvider?.getSyncToken();
    if (token != null) {
      await _flushPendingSyncOperations(token);
    }

    _hosts = await _loadAndNormalizeStoredHosts();
    notifyListeners();
  }

  Future<HostSecretModel?> getSecrets(HostModel host) async {
    return _storageService.getSecrets(host);
  }

  Future<void> saveSecrets(HostModel host, HostSecretModel secrets) async {
    await _storageService.saveSecrets(host.id, secrets);
  }

  Future<bool> _syncHostToBackend(String token, HostModel host) async {
    final updated = await _syncService.updateTerminal(token, host);
    if (updated) {
      return true;
    }

    final created = await _syncService.createTerminal(token, host);
    return created != null;
  }

  Future<void> _flushPendingSyncOperations(String token) async {
    final operations = await _storageService.loadPendingSyncOperations();
    for (final operation in operations) {
      var success = false;

      if (operation.action == PendingSyncAction.delete) {
        success = await _syncService.deleteTerminal(token, operation.hostId);
      } else if (operation.host != null) {
        success = await _syncHostToBackend(token, operation.host!);
      }

      if (success) {
        await _storageService.clearPendingSyncOperation(operation.hostId);
      }
    }
    await _refreshPendingSyncState();
  }

  Future<void> _refreshPendingSyncState() async {
    final operations = await _storageService.loadPendingSyncOperations();
    _pendingSyncHostIds = operations
        .map((operation) => operation.hostId)
        .toSet();
  }

  Future<List<HostModel>> _loadAndNormalizeStoredHosts() async {
    final hosts = await _storageService.loadHosts();
    final normalizedHosts = _normalizeHosts(hosts);
    if (!_sameHostLists(hosts, normalizedHosts)) {
      await _storageService.saveHosts(normalizedHosts);
    }
    return normalizedHosts;
  }

  List<HostModel> _normalizeHosts(List<HostModel> hosts) {
    final repairedHosts = hosts.map((host) {
      final hasDatabaseName =
          host.databaseName != null && host.databaseName!.trim().isNotEmpty;
      if (host.connectionType == ConnectionType.ssh && hasDatabaseName) {
        return host.copyWith(connectionType: ConnectionType.mysql);
      }
      return host;
    }).toList();

    final mysqlEndpoints = repairedHosts
        .where((host) => host.connectionType == ConnectionType.mysql)
        .map(_connectionEndpointKey)
        .toSet();

    return repairedHosts.where((host) {
      final looksLikeStaleMySqlDuplicate =
          host.connectionType == ConnectionType.ssh &&
          host.authType == AuthType.password &&
          mysqlEndpoints.contains(_connectionEndpointKey(host));

      return !looksLikeStaleMySqlDuplicate;
    }).toList();
  }

  String _connectionEndpointKey(HostModel host) {
    return [
      host.host.trim().toLowerCase(),
      host.port.toString(),
      host.username.trim().toLowerCase(),
    ].join('|');
  }

  bool _sameHostLists(List<HostModel> left, List<HostModel> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index].toJson().toString() != right[index].toJson().toString()) {
        return false;
      }
    }

    return true;
  }

  List<HostModel> _mergeCloudHostsWithLocal(
    List<HostModel> localHosts,
    List<HostModel> cloudHosts,
  ) {
    final localById = {for (final host in localHosts) host.id: host};
    final merged = cloudHosts.map((cloudHost) {
      final localHost = localById[cloudHost.id];
      if (localHost == null) {
        return cloudHost;
      }

      final shouldPreserveLocalMySqlType =
          localHost.connectionType == ConnectionType.mysql &&
          cloudHost.connectionType == ConnectionType.ssh &&
          (cloudHost.databaseName == null || cloudHost.databaseName!.isEmpty);

      return cloudHost.copyWith(
        name: (cloudHost.name == null || cloudHost.name!.trim().isEmpty)
            ? localHost.name
            : cloudHost.name,
        connectionType: shouldPreserveLocalMySqlType
            ? localHost.connectionType
            : cloudHost.connectionType,
        databaseName:
            (cloudHost.databaseName == null ||
                cloudHost.databaseName!.trim().isEmpty)
            ? localHost.databaseName
            : cloudHost.databaseName,
      );
    }).toList();

    final cloudIds = cloudHosts.map((host) => host.id).toSet();
    for (final localHost in localHosts) {
      if (!cloudIds.contains(localHost.id)) {
        merged.add(localHost);
      }
    }

    return merged;
  }
}
