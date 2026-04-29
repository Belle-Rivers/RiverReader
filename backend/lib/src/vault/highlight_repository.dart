import '../database/database_service.dart';

class GhostHighlight {
  final int? id;
  final int bookId;
  final String targetWord;
  final String contextSentence;
  final String cfiLocation;
  final int masteryLevel;
  final int? nextReviewDate;

  GhostHighlight({
    this.id,
    required this.bookId,
    required this.targetWord,
    required this.contextSentence,
    required this.cfiLocation,
    this.masteryLevel = 0,
    this.nextReviewDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'target_word': targetWord,
      'context_sentence': contextSentence,
      'cfi_location': cfiLocation,
      'mastery_level': masteryLevel,
      'next_review_date': nextReviewDate,
    };
  }

  factory GhostHighlight.fromMap(Map<String, dynamic> map) {
    return GhostHighlight(
      id: map['id'],
      bookId: map['book_id'],
      targetWord: map['target_word'],
      contextSentence: map['context_sentence'],
      cfiLocation: map['cfi_location'],
      masteryLevel: map['mastery_level'] ?? 0,
      nextReviewDate: map['next_review_date'],
    );
  }
}

class HighlightRepository {
  Future<int> insertHighlight(GhostHighlight highlight) async {
    final db = await DatabaseService.database;
    return await db.insert('ghost_highlights', highlight.toMap());
  }

  Future<List<GhostHighlight>> getHighlightsByBook(int bookId) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ghost_highlights',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    return List.generate(maps.length, (i) => GhostHighlight.fromMap(maps[i]));
  }
}
