import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_data.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.43.182:3000/api';

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> login(String phoneNumber, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login Error: $e');
      return false;
    }
  }

  Future<bool> register(String phoneNumber, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber, 'password': password}),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Register Error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<SystemSummary> getSystemSummary({String lang = 'en'}) async {
    try {
      debugPrint('Fetching summary from: $baseUrl/summary?lang=$lang');
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/summary?lang=$lang'), headers: headers).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return SystemSummary.fromJson(jsonDecode(response.body));
      } else {
        debugPrint('Server Error: ${response.statusCode} ${response.body}');
        throw Exception('Failed to load system summary: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Connection Error: $e');
      rethrow;
    }
  }

  Future<List<Device>> getAllDevices() async {
    try {
      debugPrint('Fetching devices from: $baseUrl/devices');
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/devices'), headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body.map((dynamic item) => Device.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load devices: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Connection Error: $e');
      rethrow;
    }
  }

  Future<RiskAssessment> getDeviceRisk(String deviceId, {String lang = 'en'}) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/device/$deviceId/risk?lang=$lang'), headers: headers);

    if (response.statusCode == 200) {
      return RiskAssessment.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load risk assessment');
    }
  }

  Future<Explanation> getDeviceExplanation(String deviceId, {String lang = 'en'}) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/device/$deviceId/explanation?lang=$lang'), headers: headers);

    if (response.statusCode == 200) {
      return Explanation.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load explanation');
    }
  }

  Future<VoiceAlert> getDeviceVoice(String deviceId, {String lang = 'en'}) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/device/$deviceId/voice?lang=$lang'), headers: headers);

    if (response.statusCode == 200) {
      return VoiceAlert.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load voice alert');
    }
  }

  Future<List<DeviceData>> getDeviceHistory(String deviceId, {int limit = 20}) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/device/$deviceId/history?limit=$limit'), headers: headers);

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => DeviceData.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load device history');
    }
  }

  Future<Map<String, dynamic>> getDeviceAnalytics(String deviceId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/device/$deviceId/analytics'), headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load analytics');
    }
  }

  Future<String> chatWithAI(String deviceId, String query) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: headers,
      body: jsonEncode({'deviceId': deviceId, 'query': query}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['answer'];
    } else {
      throw Exception('Failed to get chat response');
    }
  }
}
