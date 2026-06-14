import 'dart:convert';

import 'package:http/http.dart' as http;

class RegistrationRequest {
  const RegistrationRequest({
    required this.email,
    required this.password,
    this.securityQuestion,
    this.securityAnswer,
    this.displayName,
    this.deviceInstallId,
    this.preferredLocale,
    this.timezone,
    this.learningLevel,
  });

  final String email;
  final String password;
  final String? securityQuestion;
  final String? securityAnswer;
  final String? displayName;
  final String? deviceInstallId;
  final String? preferredLocale;
  final String? timezone;
  final String? learningLevel;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'email': email,
      'password': password,
      'security_question': securityQuestion,
      'security_answer': securityAnswer,
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
    required this.email,
    this.securityQuestion,
    this.displayName,
  });

  final String id;
  final String email;
  final String? securityQuestion;
  final String? displayName;

  factory RegistrationResponse.fromJson(Map<String, dynamic> json) {
    return RegistrationResponse(
      id: json['id'] as String,
      email: json['email'] as String,
      securityQuestion: json['security_question'] as String?,
      displayName: json['display_name'] as String?,
    );
  }
}

class RecoveryQuestionResponse {
  const RecoveryQuestionResponse({required this.email, this.securityQuestion});

  final String email;
  final String? securityQuestion;

  factory RecoveryQuestionResponse.fromJson(Map<String, dynamic> json) {
    return RecoveryQuestionResponse(
      email: json['email'] as String,
      securityQuestion: json['security_question'] as String?,
    );
  }
}

class UserProfileUpdateRequest {
  const UserProfileUpdateRequest({
    this.email,
    this.displayName,
    this.deviceInstallId,
    this.preferredLocale,
    this.timezone,
    this.learningLevel,
    this.appStoreOriginalTransactionId,
    this.appStoreProductId,
    this.subscriptionStatus,
    this.subscriptionExpiresAt,
    this.securityQuestion,
    this.securityAnswer,
  });

  final String? email;
  final String? displayName;
  final String? deviceInstallId;
  final String? preferredLocale;
  final String? timezone;
  final String? learningLevel;
  final String? appStoreOriginalTransactionId;
  final String? appStoreProductId;
  final String? subscriptionStatus;
  final String? subscriptionExpiresAt;
  final String? securityQuestion;
  final String? securityAnswer;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'email': email,
      'display_name': displayName,
      'device_install_id': deviceInstallId,
      'preferred_locale': preferredLocale,
      'timezone': timezone,
      'learning_level': learningLevel,
      'app_store_original_transaction_id': appStoreOriginalTransactionId,
      'app_store_product_id': appStoreProductId,
      'subscription_status': subscriptionStatus,
      'subscription_expires_at': subscriptionExpiresAt,
      'security_question': securityQuestion,
      'security_answer': securityAnswer,
    };
  }
}

class ResetPasswordRequest {
  const ResetPasswordRequest({
    required this.email,
    required this.securityAnswer,
    required this.newPassword,
  });

  final String email;
  final String securityAnswer;
  final String newPassword;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'email': email,
        'security_answer': securityAnswer,
        'new_password': newPassword,
      };
}

class RegistrationApiException implements Exception {
  const RegistrationApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RegistrationApiNotFoundException extends RegistrationApiException {
  const RegistrationApiNotFoundException(super.message);
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

  Future<RegistrationResponse> login(LoginRequest request) async {
    final Uri url = Uri.parse('$_defaultBaseUrl/v1/users/login');
    final http.Response response = await _client.post(
      url,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    final Map<String, dynamic>? payload = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode == 200 && payload != null) {
      return RegistrationResponse.fromJson(payload);
    }
    final Object? detail = payload?['detail'];
    throw RegistrationApiException(detail is String ? detail : 'Login failed');
  }

  Future<RegistrationResponse> getUserProfile(String id) async {
    final Uri url = Uri.parse('$_defaultBaseUrl/v1/users/$id');
    final http.Response response = await _client.get(url);
    if (response.statusCode == 200) {
      return RegistrationResponse.fromJson(jsonDecode(response.body));
    }
    if (response.statusCode == 404) {
      throw const RegistrationApiNotFoundException('User not found');
    }
    throw const RegistrationApiException('Failed to get user profile');
  }

  Future<bool> waitForBackend({
    Duration timeout = const Duration(seconds: 60),
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final Uri url = Uri.parse('$_defaultBaseUrl/health');
        final http.Response response =
            await _client.get(url).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {
        // Keep retrying until the backend wakes up.
      }
      await Future<void>.delayed(retryDelay);
    }
    return false;
  }

  Future<RecoveryQuestionResponse> getRecoveryQuestion(String email) async {
    final Uri url = Uri.parse('$_defaultBaseUrl/v1/users/recovery-question/${Uri.encodeComponent(email)}');
    final http.Response response = await _client.get(url);
    if (response.statusCode != 200) {
      throw const RegistrationApiException('Could not load recovery question');
    }
    return RecoveryQuestionResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RegistrationResponse> resetPassword(ResetPasswordRequest request) async {
    final Uri url = Uri.parse('$_defaultBaseUrl/v1/users/forgot-password');
    final http.Response response = await _client.post(
      url,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    final Map<String, dynamic>? payload = response.body.isEmpty
        ? null
        : jsonDecode(response.body) as Map<String, dynamic>?;
    if (response.statusCode == 200 && payload != null) {
      return RegistrationResponse.fromJson(payload);
    }
    final Object? detail = payload?['detail'];
    throw RegistrationApiException(detail is String ? detail : 'Password reset failed');
  }

  Future<Map<String, dynamic>> exportUserData(String userId) async {
    final Uri url = Uri.parse('$_defaultBaseUrl/v1/users/$userId/export');
    final http.Response response = await _client.get(url);
    if (response.statusCode != 200) {
      throw const RegistrationApiException('Could not export user data');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> importUserData(Map<String, dynamic> payload) async {
    final Uri url = Uri.parse('$_defaultBaseUrl/v1/users/import');
    final http.Response response = await _client.post(
      url,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      final Map<String, dynamic>? body = response.body.isEmpty
          ? null
          : jsonDecode(response.body) as Map<String, dynamic>?;
      final Object? detail = body?['detail'];
      throw RegistrationApiException(detail is String ? detail : 'Import failed');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<RegistrationResponse> updateUserProfile(String id, UserProfileUpdateRequest request) async {
    final Uri url = Uri.parse('$_defaultBaseUrl/v1/users/$id');
    final http.Response response = await _client.patch(
      url,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    final Map<String, dynamic>? payload = response.body.isEmpty
        ? null
        : jsonDecode(response.body) as Map<String, dynamic>?;
    if (response.statusCode == 200 && payload != null) {
      return RegistrationResponse.fromJson(payload);
    }
    final Object? detail = payload?['detail'];
    throw RegistrationApiException(detail is String ? detail : 'Profile update failed');
  }
}

class LoginRequest {
  const LoginRequest({required this.email, required this.password});
  final String email;
  final String password;
  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}
