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
    this.correctSentence,
    this.clashSentence,
    this.explanation,
    this.synonyms = const <String>[],
    this.misfitWord,
    this.statement,
    this.isTrue,
    this.choiceDefinitions = const <String, String>{},
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
  // context_clash
  final String? correctSentence;
  final String? clashSentence;
  final String? explanation;
  // odd_one_out
  final List<String> synonyms;
  final String? misfitWord;
  // true_or_bluff
  final String? statement;
  final bool? isTrue;
  final Map<String, String> choiceDefinitions;

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
      correctSentence: json['correct_sentence'] as String?,
      clashSentence: json['clash_sentence'] as String?,
      explanation: json['explanation'] as String?,
      synonyms: ((json['synonyms'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) => e as String)
          .toList(),
      misfitWord: json['misfit_word'] as String?,
      statement: json['statement'] as String?,
      isTrue: json['is_true'] as bool?,
      choiceDefinitions: ((json['choice_definitions'] as Map<String, dynamic>?) ?? <String, dynamic>{})
          .map((String key, dynamic value) => MapEntry<String, String>(key, value as String)),
    );
  }
}

class GameDecksBundle {
  const GameDecksBundle({
    this.cloze = const <GameDeckItemRead>[],
    this.meaningMatch = const <GameDeckItemRead>[],
    this.contextClash = const <GameDeckItemRead>[],
    this.oddOneOut = const <GameDeckItemRead>[],
    this.trueOrBluff = const <GameDeckItemRead>[],
  });

  final List<GameDeckItemRead> cloze;
  final List<GameDeckItemRead> meaningMatch;
  final List<GameDeckItemRead> contextClash;
  final List<GameDeckItemRead> oddOneOut;
  final List<GameDeckItemRead> trueOrBluff;

  factory GameDecksBundle.fromJson(Map<String, dynamic> json) {
    List<GameDeckItemRead> parseList(String key) {
      return ((json[key] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic item) => GameDeckItemRead.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return GameDecksBundle(
      cloze: parseList('cloze'),
      meaningMatch: parseList('meaning_match'),
      contextClash: parseList('context_clash'),
      oddOneOut: parseList('odd_one_out'),
      trueOrBluff: parseList('true_or_bluff'),
    );
  }
}

class GameApi {
  static const String _baseUrl = String.fromEnvironment(
    'RIVER_READER_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  Future<void> triggerBackfill(String userId) async {
    final Uri url = Uri.parse('$_baseUrl/v1/games/backfill/$userId');
    final http.Response response = await http.post(url);
    if (response.statusCode != 200) {
      throw Exception('triggerBackfill failed: ${response.statusCode} ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getCacheStatus(String userId) async {
    final Uri url = Uri.parse('$_baseUrl/v1/games/cache-status?user_id=$userId');
    final http.Response response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('getCacheStatus failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<GameDecksBundle> getAllDecks({
    required String userId,
    int limit = 8,
    bool replayRefresh = false,
  }) async {
    final Uri url = Uri.parse(
      '$_baseUrl/v1/games/decks?user_id=$userId&limit=$limit&replay_refresh=$replayRefresh',
    );
    final http.Response response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('getAllDecks failed: ${response.statusCode} ${response.body}');
    }
    return GameDecksBundle.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

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
