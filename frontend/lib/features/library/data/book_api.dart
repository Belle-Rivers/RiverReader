import 'dart:convert';
import 'package:http/http.dart' as http;

class BookApiModel {
  const BookApiModel({
    required this.id,
    required this.title,
    this.author,
    this.coverRef,
    this.progressPercent,
    this.lastReadAt,
    this.chapters = const <BookChapterApiModel>[],
  });

  final String id;
  final String title;
  final String? author;
  final String? coverRef;
  final double? progressPercent;
  final DateTime? lastReadAt;
  final List<BookChapterApiModel> chapters;

  factory BookApiModel.fromJson(Map<String, dynamic> json) {
    return BookApiModel(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      coverRef: json['cover_ref'] as String?,
      progressPercent: (json['progress_percent'] as num?)?.toDouble(),
      lastReadAt: json['last_read_at'] != null ? DateTime.parse(json['last_read_at'] as String) : null,
      chapters: ((json['chapters'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic item) => BookChapterApiModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BookChapterApiModel {
  const BookChapterApiModel({
    required this.chapterIndex,
    this.title,
    this.href,
  });
  final int chapterIndex;
  final String? title;
  final String? href;
  factory BookChapterApiModel.fromJson(Map<String, dynamic> json) {
    return BookChapterApiModel(
      chapterIndex: json['chapter_index'] as int,
      title: json['title'] as String?,
      href: json['href'] as String?,
    );
  }
}

/// Represents the last saved reading position for a book.
class ReadingProgressModel {
  const ReadingProgressModel({
    required this.bookId,
    this.cfi,
    this.chapterIndex,
    this.chapterTitle,
    this.progressPercent,
  });

  final String bookId;

  /// EPUB Canonical Fragment Identifier — exact scroll position.
  final String? cfi;
  final int? chapterIndex;
  final String? chapterTitle;
  final double? progressPercent;

  factory ReadingProgressModel.fromJson(Map<String, dynamic> json) {
    return ReadingProgressModel(
      bookId: json['book_id'] as String,
      cfi: json['cfi'] as String?,
      chapterIndex: json['chapter_index'] as int?,
      chapterTitle: json['chapter_title'] as String?,
      progressPercent: (json['progress_percent'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'cfi': cfi,
        'chapter_index': chapterIndex,
        'chapter_title': chapterTitle,
        'progress_percent': progressPercent,
      };
}

class BookChapterContentModel {
  const BookChapterContentModel({
    required this.bookId,
    required this.chapterIndex,
    required this.chapterHref,
    required this.contentHtml,
    this.contentText = '',
    this.chapterTitle,
  });
  final String bookId;
  final int chapterIndex;
  final String chapterHref;
  final String contentHtml;
  final String contentText;
  final String? chapterTitle;
  factory BookChapterContentModel.fromJson(Map<String, dynamic> json) {
    return BookChapterContentModel(
      bookId: json['book_id'] as String,
      chapterIndex: json['chapter_index'] as int,
      chapterHref: json['chapter_href'] as String,
      contentHtml: json['content_html'] as String,
      contentText: json['content_text'] as String? ?? '',
      chapterTitle: json['chapter_title'] as String?,
    );
  }
}

class BookApiException implements Exception {
  const BookApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BookApi {
  BookApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _baseUrl = String.fromEnvironment(
    'RIVER_READER_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  final http.Client _client;

  Future<List<BookApiModel>> listBooks(String userId) async {
    final Uri url = Uri.parse('$_baseUrl/v1/books?user_id=$userId');
    final http.Response response = await _client.get(url);
    if (response.statusCode != 200) {
      throw const BookApiException('Failed to load books');
    }
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((dynamic item) =>
            BookApiModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<BookApiModel> uploadBook(
    String userId,
    String filePath,
    String fileName,
    List<int> fileBytes,
  ) async {
    final Uri url = Uri.parse('$_baseUrl/v1/books/upload');
    final request = http.MultipartRequest('POST', url);
    request.fields['user_id'] = userId;
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
    ));
    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 201) {
      final Map<String, dynamic> payload =
          jsonDecode(response.body) as Map<String, dynamic>;
      return BookApiModel.fromJson(payload);
    }
    final Map<String, dynamic>? payload =
        response.body.isEmpty ? null : jsonDecode(response.body) as Map<String, dynamic>?;
    final Object? detail = payload?['detail'];
    throw BookApiException(detail is String ? detail : 'Upload failed');
  }

  Future<void> deleteBook(String userId, String bookId) async {
    final Uri url = Uri.parse('$_baseUrl/v1/books/$bookId?user_id=$userId');
    final http.Response response = await _client.delete(url);
    if (response.statusCode != 204) {
      throw const BookApiException('Failed to delete book');
    }
  }

  /// Fetches the last saved reading position for [bookId].
  /// Returns null if the user has never opened this book.
  Future<ReadingProgressModel?> getReadingProgress({
    required String userId,
    required String bookId,
  }) async {
    final Uri url =
        Uri.parse('$_baseUrl/v1/books/$bookId/progress?user_id=$userId');
    final http.Response response = await _client.get(url);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw const BookApiException('Failed to load reading progress');
    }
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    return ReadingProgressModel.fromJson(json);
  }

  /// Saves the current reading position for [bookId].
  /// Called on chapter change and when the reader is closed.
  Future<void> saveReadingProgress({
    required String userId,
    required String bookId,
    required ReadingProgressModel progress,
  }) async {
    final Uri url =
        Uri.parse('$_baseUrl/v1/books/$bookId/progress?user_id=$userId');
    final Map<String, dynamic> body = progress.toJson();
    body['user_id'] = userId;
    await _client.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    // Fire-and-forget: progress save failures are non-fatal.
    // The reader continues working even if the backend is unreachable.
  }

  Future<BookChapterContentModel> getChapterContent({
    required String userId,
    required String bookId,
    required int chapterIndex,
  }) async {
    final Uri url = Uri.parse(
      '$_baseUrl/v1/books/$bookId/chapters/$chapterIndex/content?user_id=$userId',
    );
    final http.Response response = await _client.get(url);
    if (response.statusCode != 200) {
      throw const BookApiException('Failed to load chapter content');
    }
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    return BookChapterContentModel.fromJson(json);
  }
}
