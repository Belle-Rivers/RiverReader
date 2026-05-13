import 'dart:convert';
import 'package:http/http.dart' as http;

class VaultItemRead {
  const VaultItemRead({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.targetWord,
    this.contextBefore,
    required this.contextSentence,
    this.contextAfter,
    this.chapterIndex,
    this.chapterTitle,
    this.cfi,
    required this.createdAt,
    required this.isDeleted,
    this.bookTitle,
    this.bookAuthor,
  });

  final String id;
  final String userId;
  final String bookId;
  final String targetWord;
  final String? contextBefore;
  final String contextSentence;
  final String? contextAfter;
  final int? chapterIndex;
  final String? chapterTitle;
  final String? cfi;
  final DateTime createdAt;
  final bool isDeleted;
  final String? bookTitle;
  final String? bookAuthor;

  factory VaultItemRead.fromJson(Map<String, dynamic> json) {
    return VaultItemRead(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bookId: json['book_id'] as String,
      targetWord: json['target_word'] as String,
      contextBefore: json['context_before'] as String?,
      contextSentence: json['context_sentence'] as String,
      contextAfter: json['context_after'] as String?,
      chapterIndex: json['chapter_index'] as int?,
      chapterTitle: json['chapter_title'] as String?,
      cfi: json['cfi'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
      bookTitle: json['book_title'] as String?,
      bookAuthor: json['book_author'] as String?,
    );
  }
}

class VaultApi {
  VaultApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _defaultBaseUrl = String.fromEnvironment(
    'RIVER_READER_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  final http.Client _client;

  Future<List<VaultItemRead>> listVaultItems(
    String userId, {
    String? bookId,
    String? query,
  }) async {
    final Map<String, String> queryParameters = <String, String>{
      'user_id': userId,
      'limit': '200',
    };
    if (bookId != null && bookId.isNotEmpty) {
      queryParameters['book_id'] = bookId;
    }
    if (query != null && query.trim().isNotEmpty) {
      queryParameters['q'] = query.trim();
    }
    final Uri url = Uri.parse('$_defaultBaseUrl/v1/vault').replace(
      queryParameters: queryParameters,
    );
    final http.Response response = await _client.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to load vault items');
    }
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list.map((dynamic item) => VaultItemRead.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> deleteHighlight(String highlightId, String userId) async {
    final Uri url = Uri.parse('$_defaultBaseUrl/v1/highlights/$highlightId').replace(
      queryParameters: {'user_id': userId},
    );
    final http.Response response = await _client.delete(url);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete vault item');
    }
  }
}
