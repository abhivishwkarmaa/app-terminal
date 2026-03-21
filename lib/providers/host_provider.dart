import 'package:flutter/foundation.dart';
import '../models/host_model.dart';
import '../providers/auth_provider.dart';
import '../services/sync_service.dart';
import '../services/crypto_service.dart';

class HostProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService();
  final CryptoService _cryptoService = CryptoService();
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
    final token = await _authProvider?.getValidToken();
    if (token == null) return;

    _isLoading = true;
    notifyListeners();
    try {
      final cloudHosts = await _syncService.fetchTerminals(token);
      _hosts = cloudHosts;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addHost(HostModel host, String password) async {
    final token = await _authProvider?.getValidToken();
    if (token == null) return;

    // E2EE: Encrypt password before sending to backend
    final encryptedBlob = await _cryptoService.encrypt(password);
    final hostWithBlob = host.copyWith(encryptedBlob: encryptedBlob);
    await _syncService.createTerminal(token, hostWithBlob);
    await loadHosts();
  }

  Future<void> updateHost(HostModel host, String? password) async {
    final token = await _authProvider?.getValidToken();
    if (token == null) return;

    String? encryptedBlob;
    if (password != null && password.isNotEmpty) {
      encryptedBlob = await _cryptoService.encrypt(password);
    }
    final updatedHost = host.copyWith(encryptedBlob: encryptedBlob);
    await _syncService.updateTerminal(token, updatedHost);
    await loadHosts();
  }

  Future<void> deleteHost(String id) async {
    final token = await _authProvider?.getValidToken();
    if (token == null) return;

    await _syncService.deleteTerminal(token, id);
    await loadHosts();
  }

  Future<String?> getPassword(String id) async {
    final host = _hosts.firstWhere((h) => h.id == id, orElse: () => throw Exception('Host not found'));
    if (host.encryptedBlob == null) return null;
    
    try {
      // E2EE: Decrypt password locally
      return await _cryptoService.decrypt(host.encryptedBlob!);
    } catch (e) {
      debugPrint('Decryption error for host $id: $e');
      return null;
    }
  }
}
