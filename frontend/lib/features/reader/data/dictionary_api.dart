import 'dart:convert';

import 'package:http/http.dart' as http;

/// Response from [DictionaryApi.lookupWord] matching `GET /v1/dictionary/{word}`.
class DictionaryEntryModel {
  const DictionaryEntryModel({
    required this.id,
    required this.word,
    required this.definition,
    required this.synonyms,
    this.exampleSentence,
    this.source,
  });

  final String id;
  final String word;
  final String definition;
  final List<String> synonyms;
  final String? exampleSentence;
  final String? source;

  factory DictionaryEntryModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSynonyms =
        (json['synonyms'] as List<dynamic>?) ?? <dynamic>[];
    return DictionaryEntryModel(
      id: json['id'] as String,
      word: json['word'] as String,
      definition: json['definition'] as String,
      synonyms: rawSynonyms.map((dynamic item) => item.toString()).toList(),
      exampleSentence: json['example_sentence'] as String?,
      source: json['source'] as String?,
    );
  }
}

/// Dev/admin payloads for `POST` / `PUT` / `PATCH` `/v1/dictionary`.
class DictionaryEntryUpsert {
  const DictionaryEntryUpsert({
    required this.word,
    required this.definition,
    this.synonyms = const <String>[],
    this.exampleSentence,
    this.source,
  });

  final String word;
  final String definition;
  final List<String> synonyms;
  final String? exampleSentence;
  final String? source;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'word': word,
        'definition': definition,
        'synonyms': synonyms,
        if (exampleSentence != null) 'example_sentence': exampleSentence,
        if (source != null) 'source': source,
      };
}

class DictionaryApi {
  DictionaryApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _defaultBaseUrl = String.fromEnvironment(
    'RIVER_READER_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  final http.Client _client;

  /// Returns `null` when the word is not in the dictionary (HTTP 404).
  Future<DictionaryEntryModel?> lookupWord(String word) async {
    final String trimmed = word.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final String safeWord = Uri.encodeComponent(trimmed);
    final Uri url = Uri.parse('$_defaultBaseUrl/v1/dictionary/$safeWord');
    final http.Response response = await _client.get(url);
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load dictionary entry');
    }
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    return DictionaryEntryModel.fromJson(json);
  }

  Future<DictionaryEntryModel> createEntry(DictionaryEntryUpsert body) async {
    final Uri url = Uri.parse('$_defaultBaseUrl/v1/dictionary');
    final http.Response response = await _client.post(
      url,
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(body.toJson()),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create dictionary entry: ${response.statusCode}');
    }
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    return DictionaryEntryModel.fromJson(json);
  }

  Future<DictionaryEntryModel> upsertEntry(String word, DictionaryEntryUpsert body) async {
    final String safeWord = Uri.encodeComponent(word.trim());
    final Uri url = Uri.parse('$_defaultBaseUrl/v1/dictionary/$safeWord');
    final http.Response response = await _client.put(
      url,
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(body.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to upsert dictionary entry: ${response.statusCode}');
    }
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    return DictionaryEntryModel.fromJson(json);
  }
}
