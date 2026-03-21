import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { offline, sync }

extension AppModeX on AppMode {
  String get storageValue {
    switch (this) {
      case AppMode.offline:
        return 'offline';
      case AppMode.sync:
        return 'sync';
    }
  }

  String get label {
    switch (this) {
      case AppMode.offline:
        return 'Offline Mode';
      case AppMode.sync:
        return 'Sync Mode';
    }
  }

  String get description {
    switch (this) {
      case AppMode.offline:
        return 'No backend interaction. Hosts and credentials stay only on this device.';
      case AppMode.sync:
        return 'Host metadata syncs with your backend. Private keys and passwords stay on-device.';
    }
  }

  static AppMode? fromStorageValue(String? value) {
    switch (value) {
      case 'offline':
        return AppMode.offline;
      case 'sync':
        return AppMode.sync;
      default:
        return null;
    }
  }
}

class AppModeProvider extends ChangeNotifier {
  static const String _modeKey = 'app_mode';

  AppMode? _mode;
  bool _isLoading = true;

  AppMode? get mode => _mode;
  bool get isLoading => _isLoading;
  bool get isOfflineMode => _mode == AppMode.offline;
  bool get isSyncMode => _mode == AppMode.sync;
  bool get hasSelectedMode => _mode != null;

  AppModeProvider() {
    _load();
  }

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    _mode = AppModeX.fromStorageValue(prefs.getString(_modeKey));
    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectMode(AppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.storageValue);
    _mode = mode;
    notifyListeners();
  }
}
