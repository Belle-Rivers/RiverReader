import 'dart:convert';

import 'package:http/http.dart' as http;

class RegistrationRequest {
  const RegistrationRequest({
    required this.username,
    this.displayName,
    this.deviceInstallId,
    this.preferredLocale,
    this.timezone,
    this.learningLevel,
  });

  final String username;
  final String? displayName;
  final String? deviceInstallId;
  final String? preferredLocale;
  final String? timezone;
  final String? learningLevel;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'username': username,
      'display_name': displayName,
      'device_install_id': deviceInstallId,
      'preferred_locale': preferredLocale,
      'timezone': timezone,
      'learning_level': learningLevel,
    };
  }
}

class RegistrationResponse {
  const RegistrationResponse({
    required this.id,
    required this.username,
    this.displayName,
  });

  final String id;
  final String username;
  final String? displayName;

  factory RegistrationResponse.fromJson(Map<String, dynamic> json) {
    return RegistrationResponse(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
    );
  }
}

class RegistrationApiException implements Exception {
  const RegistrationApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RegistrationApi {
  RegistrationApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _defaultBaseUrl = String.fromEnvironment(
    'RIVER_READER_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  final http.Client _client;

  Future<RegistrationResponse> register(RegistrationRequest request) async {
    final Uri url = Uri.parse('$_defaultBaseUrl/v1/users/register');
    final http.Response response = await _client.post(
      url,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    final Map<String, dynamic>? payload = response.body.isEmpty
        ? null
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201 && payload != null) {
      return RegistrationResponse.fromJson(payload);
    }

    final Object? detail = payload?['detail'];
    throw RegistrationApiException(
      detail is String ? detail : 'Registration failed (${response.statusCode})',
    );
  }

  Future<List<RegistrationResponse>> listUserProfiles() async {
    final Uri url = Uri.parse('$_defaultBaseUrl/v1/users');
    final http.Response response = await _client.get(url);
    if (response.statusCode != 200) {
      final Map<String, dynamic>? payload = response.body.isEmpty
          ? null
          : jsonDecode(response.body) as Map<String, dynamic>?;
      final Object? detail = payload?['detail'];
      throw RegistrationApiException(
        detail is String ? detail : 'Could not load profiles (${response.statusCode})',
      );
    }
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((dynamic item) => RegistrationResponse.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<RegistrationResponse> findProfileByUsername(String username) async {
    final String normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const RegistrationApiException('Username is required');
    }
    final List<RegistrationResponse> profiles = await listUserProfiles();
    for (final RegistrationResponse profile in profiles) {
      if (profile.username.toLowerCase() == normalized) {
        return profile;
      }
    }
    throw const RegistrationApiException('No profile found for that username');
  }
}
