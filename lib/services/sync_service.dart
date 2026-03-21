import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/host_model.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  // Use desktop IP if on real phone for android/ios. 10.0.2.2 is special for Android Emulator.
  // For iOS simulator, localhost/127.0.0.1 is fine.
  static String get _baseUrl {
    return 'http://192.142.3.54:8080/api';
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<List<HostModel>> fetchTerminals(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/terminals'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => HostModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<HostModel?> createTerminal(String token, HostModel host) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/terminals'),
        headers: _headers(token),
        body: jsonEncode(host.toJson()),
      );
      
      if (response.statusCode == 201) {
        return HostModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateTerminal(String token, HostModel host) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/terminals/${host.id}'),
        headers: _headers(token),
        body: jsonEncode(host.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTerminal(String token, String hostId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/terminals/$hostId'),
        headers: _headers(token),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Sync Error: $e');
      return false;
    }
  }
}
