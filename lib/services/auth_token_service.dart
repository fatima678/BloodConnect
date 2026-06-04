// lib/services/auth_token_service.dart

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthTokenService {
  static const String baseUrl =
      'https://manliness-smugness-qualm.ngrok-free.dev/api';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static Map<String, dynamic>? getUser() {
  // Agar aap data SharedPreferences ya kisi class memory cache me save karte hain, usey yahan return karein
  // Example placeholder logic:
  return null; 
}
  static const String _tokenKey = 'user_token';
  static const String _refreshTokenKey = 'user_refresh_token';
  static const String _expiresAtKey = 'user_token_expires_at';
  static const String _userDataKey = 'user_data';

  // ==================== SESSION MANAGEMENT ====================

  static Future<void> saveSession({
    required String token,
    required String refreshToken,
    required int expiresIn,
    required Map<String, dynamic> user,
  }) async {
    final int expiresAt = DateTime.now()
        .add(Duration(seconds: expiresIn))
        .millisecondsSinceEpoch;

    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _expiresAtKey, value: expiresAt.toString());
    await _storage.write(key: _userDataKey, value: jsonEncode(user));
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final String? userJson = await _storage.read(key: _userDataKey);
    if (userJson == null || userJson.isEmpty) return null;
    return jsonDecode(userJson) as Map<String, dynamic>;
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expiresAtKey);
    await _storage.delete(key: _userDataKey);
  }

  // ==================== TOKEN VALIDATION ====================

  static Future<bool> isTokenExpiredOrNearExpiry() async {
    final String? expiresAtString = await _storage.read(key: _expiresAtKey);
    if (expiresAtString == null || expiresAtString.isEmpty) return true;

    final int? expiresAt = int.tryParse(expiresAtString);
    if (expiresAt == null) return true;

    final int now = DateTime.now().millisecondsSinceEpoch;
    return now >= (expiresAt - 60000); // Refresh 60 seconds before expiry
  }

  static Future<String> getValidToken() async {
    final String? token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('User token missing. Please login again.');
    }

    final bool shouldRefresh = await isTokenExpiredOrNearExpiry();
    if (!shouldRefresh) return token;

    return refreshToken();
  }

  // ==================== TOKEN REFRESH ====================

  static Future<String> refreshToken() async {
    final String? refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await clearSession();
      throw Exception('Refresh token missing. Please login again.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/refresh-token'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({'refresh_token': refreshToken}),
    ).timeout(const Duration(seconds: 15));

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode != 200 || data['success'] != true) {
      await clearSession();
      throw Exception(data['message'] ?? 'Session expired. Please login again.');
    }

    final String? newToken = data['token'];
    final String? newRefreshToken = data['refresh_token'];
    final int expiresIn = int.tryParse('${data['expires_in'] ?? 3600}') ?? 3600;

    if (newToken == null || newToken.isEmpty) {
      await clearSession();
      throw Exception('New token not received from server.');
    }

    final Map<String, dynamic>? currentUser = await getUserData();

    await saveSession(
      token: newToken,
      refreshToken: newRefreshToken ?? refreshToken,
      expiresIn: expiresIn,
      user: currentUser ?? Map<String, dynamic>.from(data['data'] ?? {}),
    );

    return newToken;
  }

  // ==================== AUTHORIZED REQUESTS ====================

  static Future<http.Response> authorizedGet(String endpoint) async {
    String token = await getValidToken();

    http.Response response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 401) {
      token = await refreshToken();
      response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));
    }

    return response;
  }

  static Future<http.Response> authorizedPost(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    String token = await getValidToken();

    http.Response response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 401) {
      token = await refreshToken();
      response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 20));
    }

    return response;
  }

  // ==================== NEW: AUTHORIZED PUT ====================
  static Future<http.Response> authorizedPut(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    String token = await getValidToken();

    http.Response response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 401) {
      token = await refreshToken();
      response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 20));
    }

    return response;
  }
}