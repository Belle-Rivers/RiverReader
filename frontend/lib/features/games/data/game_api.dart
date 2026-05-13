import 'dart:convert';

import 'package:http/http.dart' as http;

class GameDeckItemRead {
  const GameDeckItemRead({
    required this.gameType,
    required this.highlightId,
    required this.srsItemId,
    required this.targetWord,
    required this.prompt,
    required this.choices,
    required this.correctAnswer,
    this.definition,
    this.bookTitle,
  });

  final String gameType;
  final String highlightId;
  final String srsItemId;
  final String targetWord;
  final String prompt;
  final List<String> choices;
  final String correctAnswer;
  final String? definition;
  final String? bookTitle;

  factory GameDeckItemRead.fromJson(Map<String, dynamic> json) {
    return GameDeckItemRead(
      gameType: json['game_type'] as String,
      highlightId: json['highlight_id'] as String,
      srsItemId: json['srs_item_id'] as String,
      targetWord: json['target_word'] as String,
      prompt: json['prompt'] as String,
      choices: ((json['choices'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) => e as String)
          .toList(),
      correctAnswer: json['correct_answer'] as String,
      definition: json['definition'] as String?,
      bookTitle: json['book_title'] as String?,
    );
  }
}

class GameApi {
  static const String _baseUrl = String.fromEnvironment(
    'RIVER_READER_API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  Future<List<GameDeckItemRead>> getDeck({
    required String userId,
    required String type,
    int limit = 10,
  }) async {
    final Uri url = Uri.parse(
      '$_baseUrl/v1/games/deck?user_id=$userId&type=$type&limit=$limit',
    );
    final http.Response response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('getDeck failed: ${response.statusCode} ${response.body}');
    }
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((dynamic item) => GameDeckItemRead.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> submitAnswer({
    required String userId,
    required String srsItemId,
    required String gameType,
    required String? selectedAnswer,
    required bool isCorrect,
    int comboMultiplier = 1,
    int xpEarned = 0,
    int? responseTimeMs,
  }) async {
    final Uri url = Uri.parse('$_baseUrl/v1/games/answer');
    final Map<String, dynamic> body = <String, dynamic>{
      'user_id': userId,
      'srs_item_id': srsItemId,
      'game_type': gameType,
      'selected_answer': selectedAnswer,
      'is_correct': isCorrect,
      'grade': isCorrect ? 4 : 0,
      'combo_multiplier': comboMultiplier,
      'xp_earned': xpEarned,
      'response_time_ms': responseTimeMs,
    };
    final http.Response response = await http.post(
      url,
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('submitAnswer failed: ${response.statusCode} ${response.body}');
    }
  }
}
