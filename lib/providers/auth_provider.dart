import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/backend_config.dart';

class AuthProvider extends ChangeNotifier {
  static const String _cachedUserKey = 'cached_backend_user';

  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  BackendUser? _user;
  String? _token;
  bool _isAuthLoading = true;
  bool _isBackendAvailable = false;
  Future<bool>? _refreshFuture;

  BackendUser? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _user != null; // User MUST exist too
  bool get isAuthLoading => _isAuthLoading;
  bool get isBackendAvailable => _isBackendAvailable;

  AuthProvider() {
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    _isAuthLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isFirstRun = prefs.getBool('is_first_run_after_install') ?? true;
      
      if (isFirstRun) {
        // ON IOS, Keychain persists after delete. We must clear it on fresh install.
        await _storage.deleteAll();
        await prefs.setBool('is_first_run_after_install', false);
      }

      _loadCachedUser(prefs);

      _token = await _storage.read(key: 'jwt_token');
      if (_token != null) {
        final backendAvailable = await checkBackendHealth();
        final validToken = await getValidToken();
        if (validToken != null && backendAvailable) {
          await fetchProfile();
        } else if (validToken == null) {
          await logout();
        }
      }
    } catch (e) {
      debugPrint('Error during initial auth check: $e');
    } finally {
      _isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      String? clientId;
      if (kIsWeb) {
        clientId = '440931751926-vntgll7vd9ph440euho89o8iqrvisado.apps.googleusercontent.com';
      } else if (Platform.isIOS) {
        clientId = '440931751926-0a9t8hk0l0ncvibeld34ju0t0v23o2mv.apps.googleusercontent.com';
      } else if (Platform.isAndroid) {
        clientId = '440931751926-6afnp9pqiv70sao6mg68q1v1pe8fil8a.apps.googleusercontent.com';
      }

      await _googleSignIn.initialize(
        clientId: clientId,
        serverClientId: '440931751926-vntgll7vd9ph440euho89o8iqrvisado.apps.googleusercontent.com',
      );
      _initialized = true;
    }
  }

  Future<bool> login() async {
    try {
      await _ensureInitialized();
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) return false;

      final backendAvailable = await checkBackendHealth();
      if (!backendAvailable) {
        debugPrint('Login blocked because backend health check failed.');
        return false;
      }

      debugPrint('Attempting login at: ${BackendConfig.baseUrl}/auth/google');
      final response = await http.post(
        Uri.parse('${BackendConfig.baseUrl}/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String? token = data['token']?.toString();
        final String? refreshToken = data['refresh_token']?.toString();
        
        if (token == null || refreshToken == null) {
          debugPrint('Login failed: Token(s) missing from response: ${response.body}');
          return false;
        }

        _token = token;
        await _storage.write(key: 'jwt_token', value: _token!);
        await _storage.write(key: 'refresh_token', value: refreshToken);

        await fetchProfile();
        notifyListeners();
        return true;
      } else {
        debugPrint('Login failed with status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<String?> getValidToken() async {
    if (_token == null) return null;

    if (_isTokenExpired(_token!)) {
      if (!_isBackendAvailable) {
        return _token;
      }
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        return null;
      }
    }

    return _token;
  }

  Future<String?> getSyncToken() async {
    if (_token == null) return null;

    final backendAvailable = await checkBackendHealth();
    if (!backendAvailable) {
      return null;
    }

    if (_isTokenExpired(_token!)) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        return null;
      }
    }

    return _token;
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> claims = jsonDecode(decoded);
      final exp = claims['exp'];

      if (exp is! num) return true;

      final expiry = DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      );

      return expiry.isBefore(DateTime.now().toUtc().add(const Duration(minutes: 1)));
    } catch (e) {
      debugPrint('Token parse error: $e');
      return true;
    }
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    _refreshFuture = _performRefreshTokenRequest();
    final result = await _refreshFuture!;
    _refreshFuture = null;
    return result;
  }

  Future<bool> _performRefreshTokenRequest() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      if (!await checkBackendHealth()) {
        return false;
      }

      final response = await http.post(
        Uri.parse('${BackendConfig.baseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode != 200) {
        debugPrint('Refresh token failed: ${response.statusCode} ${response.body}');
        if (response.statusCode == 401) {
          await _storage.delete(key: 'jwt_token');
          await _storage.delete(key: 'refresh_token');
          _token = null;
          _user = null;
          await _clearCachedUser();
          notifyListeners();
        }
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final newToken = data['token']?.toString();
      final newRefreshToken = data['refresh_token']?.toString();

      if (newToken == null || newRefreshToken == null) {
        debugPrint('Refresh token response missing fields: ${response.body}');
        return false;
      }

      _token = newToken;
      await _storage.write(key: 'jwt_token', value: newToken);
      await _storage.write(key: 'refresh_token', value: newRefreshToken);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Refresh token error: $e');
      return false;
    }
  }

  Future<void> fetchProfile() async {
    final backendAvailable = await checkBackendHealth();
    if (!backendAvailable) return;

    final token = await getValidToken();
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${BackendConfig.apiBaseUrl}/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        _user = BackendUser.fromJson(jsonDecode(response.body));
        await _persistCachedUser();
        notifyListeners();
      } else if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (!refreshed) {
          debugPrint('Session invalid (Status: ${response.statusCode}), logging out.');
          await logout();
          return;
        }
        await fetchProfile();
      } else if (response.statusCode == 404) {
        debugPrint('User not found (Status: ${response.statusCode}), logging out.');
        await logout();
      }
    } catch (e) {
      debugPrint('Fetch profile error: $e');
    }
  }

  Future<bool> updateProfile(String newName) async {
    final token = await getSyncToken();
    if (token == null) return false;

    try {
      final response = await http.put(
        Uri.parse('${BackendConfig.apiBaseUrl}/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': newName}),
      );
      if (response.statusCode == 200) {
        await fetchProfile();
        return true;
      }
      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          return updateProfile(newName);
        }
        await logout();
      }
      return false;
    } catch (e) {
      debugPrint('Update profile error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
    _token = null;
    _user = null;
    _isBackendAvailable = false;
    await _clearCachedUser();
    notifyListeners();
  }

  Future<bool> checkBackendHealth() async {
    try {
      final response = await http
          .get(Uri.parse('${BackendConfig.baseUrl}/health'))
          .timeout(const Duration(seconds: 3));
      final available = response.statusCode == 200;
      _updateBackendAvailability(available);
      return available;
    } catch (_) {
      _updateBackendAvailability(false);
      return false;
    }
  }

  void _updateBackendAvailability(bool isAvailable) {
    if (_isBackendAvailable == isAvailable) return;
    _isBackendAvailable = isAvailable;
    notifyListeners();
  }

  void _loadCachedUser(SharedPreferences prefs) {
    final cachedUserJson = prefs.getString(_cachedUserKey);
    if (cachedUserJson == null || cachedUserJson.isEmpty) {
      return;
    }

    try {
      _user = BackendUser.fromJson(
        jsonDecode(cachedUserJson) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('Cached user decode error: $e');
    }
  }

  Future<void> _persistCachedUser() async {
    final user = _user;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cachedUserKey,
      jsonEncode(user.toJson()),
    );
  }

  Future<void> _clearCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedUserKey);
  }
}
