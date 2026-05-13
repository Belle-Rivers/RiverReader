import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HighlightCreateModel {
  const HighlightCreateModel({
    required this.userId,
    required this.bookId,
    required this.targetWord,
    this.contextBefore,
    required this.contextSentence,
    this.contextAfter,
    this.chapterIndex,
    this.chapterTitle,
    this.cfi,
  });

  final String userId;
  final String bookId;
  final String targetWord;
  final String? contextBefore;
  final String contextSentence;
  final String? contextAfter;
  final int? chapterIndex;
  final String? chapterTitle;
  final String? cfi;

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'book_id': bookId,
        'target_word': targetWord,
        'context_before': contextBefore,
        'context_sentence': contextSentence,
        'context_after': contextAfter,
        'chapter_index': chapterIndex,
        'chapter_title': chapterTitle,
        'cfi': cfi,
      };

  factory HighlightCreateModel.fromJson(Map<String, dynamic> json) {
    return HighlightCreateModel(
      userId: json['user_id'] as String,
      bookId: json['book_id'] as String,
      targetWord: json['target_word'] as String,
      contextBefore: json['context_before'] as String?,
      contextSentence: json['context_sentence'] as String,
      contextAfter: json['context_after'] as String?,
      chapterIndex: json['chapter_index'] as int?,
      chapterTitle: json['chapter_title'] as String?,
      cfi: json['cfi'] as String?,
    );
  }
}

class HighlightApiException implements Exception {
  const HighlightApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class HighlightApi {
  HighlightApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _baseUrl = String.fromEnvironment(
    'RIVER_READER_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String _offlineQueueKey = 'offline_highlights_queue';

  final http.Client _client;

  Future<void> createHighlight(HighlightCreateModel highlight) async {
    try {
      await _postHighlight(highlight);
    } catch (_) {
      await _queueOfflineHighlight(
        PendingHighlight.fromHighlight(highlight),
      );
    }
  }

  Future<void> _postHighlight(HighlightCreateModel highlight) async {
    final Uri url = Uri.parse('$_baseUrl/v1/highlights');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(highlight.toJson()),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw const HighlightApiException('Failed to create highlight');
    }
  }
  Future<void> _queueOfflineHighlight(PendingHighlight highlight) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<PendingHighlight> queue = await _readOfflineQueue(prefs);
    queue.add(highlight);
    await _writeOfflineQueue(prefs, queue);
  }
  Future<List<PendingHighlight>> _readOfflineQueue(
    SharedPreferences prefs,
  ) async {
    final String? raw = prefs.getString(_offlineQueueKey);
    if (raw == null || raw.isEmpty) {
      return <PendingHighlight>[];
    }
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (dynamic item) => PendingHighlight.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }
  Future<void> _writeOfflineQueue(
    SharedPreferences prefs,
    List<PendingHighlight> queue,
  ) async {
    final List<Map<String, dynamic>> payload =
        queue.map((PendingHighlight item) => item.toJson()).toList();
    await prefs.setString(_offlineQueueKey, jsonEncode(payload));
  }

  /// Tries to sync all offline queued highlights. Should be called on app launch or network resume.
  Future<void> syncOfflineHighlights() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<PendingHighlight> queue = await _readOfflineQueue(prefs);
    if (queue.isEmpty) return;
    final List<PendingHighlight> failedItems = <PendingHighlight>[];
    for (final PendingHighlight item in queue) {
      try {
        await _postHighlight(item.toHighlightCreateModel());
      } catch (_) {
        failedItems.add(item);
      }
    }
    await _writeOfflineQueue(prefs, failedItems);
  }
}

class PendingHighlight {
  const PendingHighlight({
    required this.targetWord,
    required this.contextSentence,
    this.contextBefore,
    this.contextAfter,
    required this.bookId,
    required this.userId,
    this.cfi,
    this.chapterTitle,
    this.chapterIndex,
    required this.capturedAt,
  });
  final String targetWord;
  final String contextSentence;
  final String? contextBefore;
  final String? contextAfter;
  final String bookId;
  final String userId;
  final String? cfi;
  final String? chapterTitle;
  final int? chapterIndex;
  final DateTime capturedAt;
  factory PendingHighlight.fromHighlight(HighlightCreateModel highlight) {
    return PendingHighlight(
      targetWord: highlight.targetWord,
      contextSentence: highlight.contextSentence,
      contextBefore: highlight.contextBefore,
      contextAfter: highlight.contextAfter,
      bookId: highlight.bookId,
      userId: highlight.userId,
      cfi: highlight.cfi,
      chapterTitle: highlight.chapterTitle,
      chapterIndex: highlight.chapterIndex,
      capturedAt: DateTime.now().toUtc(),
    );
  }
  factory PendingHighlight.fromJson(Map<String, dynamic> json) {
    return PendingHighlight(
      targetWord: json['target_word'] as String,
      contextSentence: json['context_sentence'] as String,
      contextBefore: json['context_before'] as String?,
      contextAfter: json['context_after'] as String?,
      bookId: json['book_id'] as String,
      userId: json['user_id'] as String,
      cfi: json['cfi'] as String?,
      chapterTitle: json['chapter_title'] as String?,
      chapterIndex: json['chapter_index'] as int?,
      capturedAt: DateTime.parse(json['captured_at'] as String),
    );
  }
  Map<String, dynamic> toJson() => <String, dynamic>{
        'target_word': targetWord,
        'context_sentence': contextSentence,
        'context_before': contextBefore,
        'context_after': contextAfter,
        'book_id': bookId,
        'user_id': userId,
        'cfi': cfi,
        'chapter_title': chapterTitle,
        'chapter_index': chapterIndex,
        'captured_at': capturedAt.toIso8601String(),
      };
  HighlightCreateModel toHighlightCreateModel() {
    return HighlightCreateModel(
      userId: userId,
      bookId: bookId,
      targetWord: targetWord,
      contextSentence: contextSentence,
      contextBefore: contextBefore,
      contextAfter: contextAfter,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      cfi: cfi,
    );
  }
}
