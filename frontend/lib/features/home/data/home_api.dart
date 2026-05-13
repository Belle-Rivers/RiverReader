import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../library/data/book_api.dart';
import '../../vault/data/vault_api.dart';

class HomeStatsModel {
  const HomeStatsModel({
    required this.booksCount,
    required this.vaultCount,
    required this.dueReviewsCount,
  });

  final int booksCount;
  final int vaultCount;
  final int dueReviewsCount;

  factory HomeStatsModel.fromJson(Map<String, dynamic> json) {
    return HomeStatsModel(
      booksCount: (json['books_count'] as num).toInt(),
      vaultCount: (json['vault_count'] as num).toInt(),
      dueReviewsCount: (json['due_reviews_count'] as num).toInt(),
    );
  }
}

/// Response from `GET /v1/me/home` — stats, resume reading, and recent vault captures.
class HomeSummaryModel {
  const HomeSummaryModel({
    required this.stats,
    this.lastOpenedBook,
    this.lastProgress,
    this.recentVaultWords = const <VaultItemRead>[],
    this.displayName,
  });

  final HomeStatsModel stats;
  final BookApiModel? lastOpenedBook;
  final ReadingProgressModel? lastProgress;
  final List<VaultItemRead> recentVaultWords;
  final String? displayName;

  factory HomeSummaryModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? userJson = json['user'] as Map<String, dynamic>?;
    final Map<String, dynamic> statsJson = json['stats'] as Map<String, dynamic>;
    final Map<String, dynamic>? bookJson = json['last_opened_book'] as Map<String, dynamic>?;
    final Map<String, dynamic>? progressJson = json['last_progress'] as Map<String, dynamic>?;
    final List<dynamic> recentRaw = json['recent_vault_words'] as List<dynamic>? ?? <dynamic>[];
    return HomeSummaryModel(
      stats: HomeStatsModel.fromJson(statsJson),
      lastOpenedBook: bookJson != null ? BookApiModel.fromJson(bookJson) : null,
      lastProgress: progressJson != null ? ReadingProgressModel.fromJson(progressJson) : null,
      recentVaultWords: recentRaw
          .map((dynamic e) => VaultItemRead.fromJson(e as Map<String, dynamic>))
          .toList(),
      displayName: userJson?['display_name'] as String?,
    );
  }
}

class HomeApiException implements Exception {
  const HomeApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class HomeApi {
  HomeApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _baseUrl = String.fromEnvironment(
    'RIVER_READER_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  final http.Client _client;

  Future<HomeSummaryModel> fetchHome(String userId) async {
    final Uri url = Uri.parse('$_baseUrl/v1/me/home').replace(
      queryParameters: <String, String>{'user_id': userId},
    );
    final http.Response response = await _client.get(url);
    if (response.statusCode == 404) {
      throw const HomeApiException('User not found');
    }
    if (response.statusCode != 200) {
      throw const HomeApiException('Failed to load home');
    }
    final Map<String, dynamic> json = jsonDecode(response.body) as Map<String, dynamic>;
    return HomeSummaryModel.fromJson(json);
  }
}
