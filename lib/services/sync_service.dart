import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/host_model.dart';
import 'backend_config.dart';

class SyncService {
  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<List<HostModel>> fetchTerminals(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${BackendConfig.apiBaseUrl}/terminals'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => HostModel.fromJson(json)).toList();
      }
      debugPrint(
        'Fetch terminals failed: ${response.statusCode} ${response.body}',
      );
      return [];
    } catch (e) {
      debugPrint('Fetch terminals error: $e');
      return [];
    }
  }

  Future<HostModel?> createTerminal(String token, HostModel host) async {
    try {
      final response = await http.post(
        Uri.parse('${BackendConfig.apiBaseUrl}/terminals'),
        headers: _headers(token),
        body: jsonEncode(host.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return HostModel.fromJson(jsonDecode(response.body));
      }
      debugPrint(
        'Create terminal failed: ${response.statusCode} ${response.body}',
      );
      return null;
    } catch (e) {
      debugPrint('Create terminal error: $e');
      return null;
    }
  }

  Future<bool> updateTerminal(String token, HostModel host) async {
    try {
      final response = await http.put(
        Uri.parse('${BackendConfig.apiBaseUrl}/terminals/${host.id}'),
        headers: _headers(token),
        body: jsonEncode(host.toJson()),
      );
      if (response.statusCode != 200) {
        debugPrint(
          'Update terminal failed: ${response.statusCode} ${response.body}',
        );
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Update terminal error: $e');
      return false;
    }
  }

  Future<bool> deleteTerminal(String token, String hostId) async {
    try {
      final response = await http.delete(
        Uri.parse('${BackendConfig.apiBaseUrl}/terminals/$hostId'),
        headers: _headers(token),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Sync Error: $e');
      return false;
    }
  }
}
