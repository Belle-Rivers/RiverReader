import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../library/data/book_api.dart';
import '../../vault/data/highlight_api.dart';
import '../../auth/application/current_user_provider.dart';
import '../../vault/application/vault_provider.dart';
import '../controllers/reader_controller.dart';
import '../controllers/reader_preferences_provider.dart';
import '../data/dictionary_api.dart';
import 'web_helper.dart';

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    required this.bookId,
    this.bookExtra,
  });

  final String bookId;
  final Object? bookExtra;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  static const String _ghostCaptureHandlerName = 'ghostCapture';
  static const String _dictionaryHintHandlerName = 'dictionaryHint';
  static const String _dictionaryDismissHandlerName = 'dictionaryDismiss';
  static const String _webBridgeConsolePrefix = 'RiverReaderBridge:';
  static const String _chapterNavigationHandlerName = 'chapterNavigation';
  static const double _minReaderFontSize = 14;
  static const double _maxReaderFontSize = 28;
  InAppWebViewController? _webViewController;
  int _activeChapterIndex = 0;
  String? _activeChapterTitle;
  String? _chapterHtml;
  double _readerFontSize = 18;
  double _progressPercent = 0;
  bool _isChapterLoading = true;
  String? _chapterLoadError;
  _ReaderDictHint? _dictHint;
  Timer? _dictHintTimer;
  final Map<int, BookChapterContentModel> _chapterCache = {};
  bool _isIndexSheetOpen = false;
  BookApiModel? _resolvedBook;

  @override
  void initState() {
    super.initState();
    ref.read(readerPreferencesProvider.notifier).init();
    if (kIsWeb) {
      initWebPostMessageListener(_handleReaderBridgeConsoleMessage);
    }
    Future<void>.microtask(_initializeReader);
  }

  void _reloadChapterForFontChange() {
    unawaited(_syncChapterToWebView());
  }

  void _showCaptureFeedback() {
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _dictHintTimer?.cancel();
    super.dispose();
  }

  void _dismissDictHint() {
    _dictHintTimer?.cancel();
    _dictHintTimer = null;
    if (_dictHint != null && mounted) {
      setState(() => _dictHint = null);
    }
  }

  void _scheduleDictHintDismiss() {
    _dictHintTimer?.cancel();
    _dictHintTimer = Timer(const Duration(seconds: 8), _dismissDictHint);
  }

  Future<void> _handleDictionaryHintPayload(Map<String, dynamic> payload) async {
    final Object? wordRaw = payload['target_word'];
    final Object? yRaw = payload['client_y'];
    if (wordRaw is! String || wordRaw.isEmpty) {
      return;
    }
    final double anchorY = yRaw is num ? yRaw.toDouble() : 48;
    if (!mounted) {
      return;
    }
    setState(() {
      _dictHint = _ReaderDictHint(
        word: wordRaw,
        anchorY: anchorY,
        loading: true,
        body: '',
      );
    });
    _scheduleDictHintDismiss();
    try {
      final DictionaryEntryModel? entry =
          await ref.read(dictionaryApiProvider).lookupWord(wordRaw);
      if (!mounted) {
        return;
      }
      final String body = entry == null
          ? 'No hint available.'
          : entry.synonyms.isEmpty
              ? entry.definition
              : '${entry.definition}\n\nSynonyms: ${entry.synonyms.join(', ')}';
      setState(() {
        _dictHint = _ReaderDictHint(
          word: wordRaw,
          anchorY: anchorY,
          loading: false,
          body: body,
        );
      });
      _scheduleDictHintDismiss();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _dictHint = _ReaderDictHint(
          word: wordRaw,
          anchorY: anchorY,
          loading: false,
          body: 'No hint available.',
        );
      });
      _scheduleDictHintDismiss();
    }
  }

  void _handleChapterNavigationPayload(Map<String, dynamic> payload) {
    final String? targetHref = payload['href'] as String?;
    if (targetHref == null || targetHref.isEmpty) {
      return;
    }
    final List<BookChapterApiModel> chapters = _bookChapters();
    for (final BookChapterApiModel ch in chapters) {
      if (ch.href != null && ch.href == targetHref) {
        unawaited(
          _loadChapterContent(
            chapterIndex: ch.chapterIndex,
            persistProgress: true,
          ),
        );
        break;
      }
    }
  }

  void _handleGhostCapturePayload(Map<String, dynamic> payload) {
    final String? userId = ref.read(sessionUserIdProvider);
    if (userId == null) {
      return;
    }
    final HighlightCreateModel? highlight = _buildHighlightFromBridgePayload(
      userId: userId,
      bookId: widget.bookId,
      payload: payload,
    );
    if (highlight == null) {
      return;
    }
    _showCaptureFeedback();
    _captureHighlightSilently(
      ref: ref,
      highlight: highlight,
    );
  }

  void _handleReaderBridgeConsoleMessage(String? message) {
    if (message == null || !message.startsWith(_webBridgeConsolePrefix)) {
      return;
    }
    final String rawPayload = message.substring(_webBridgeConsolePrefix.length);
    try {
      final Object? decoded = jsonDecode(rawPayload);
      if (decoded is! Map) {
        return;
      }
      final Map<String, dynamic> bridgeMessage =
          Map<String, dynamic>.from(decoded);
      final Object? handlerRaw = bridgeMessage['handler'];
      final Object? payloadRaw = bridgeMessage['payload'];
      final Map<String, dynamic> payload = payloadRaw is Map
          ? Map<String, dynamic>.from(payloadRaw)
          : <String, dynamic>{};
      switch (handlerRaw) {
        case _ghostCaptureHandlerName:
          _handleGhostCapturePayload(payload);
          break;
        case _dictionaryHintHandlerName:
          unawaited(_handleDictionaryHintPayload(payload));
          break;
        case _dictionaryDismissHandlerName:
          _dismissDictHint();
          break;
        case _chapterNavigationHandlerName:
          _handleChapterNavigationPayload(payload);
          break;
      }
    } catch (_) {
      return;
    }
  }

  HighlightCreateModel? _buildHighlightFromBridgePayload({
    required String userId,
    required String bookId,
    required Map<String, dynamic> payload,
  }) {
    final dynamic targetWordRaw = payload['target_word'];
    final dynamic contextSentenceRaw = payload['context_sentence'];
    if (targetWordRaw is! String || targetWordRaw.isEmpty) {
      return null;
    }
    if (contextSentenceRaw is! String || contextSentenceRaw.isEmpty) {
      return null;
    }
    return HighlightCreateModel(
      userId: userId,
      bookId: bookId,
      targetWord: targetWordRaw,
      contextSentence: contextSentenceRaw,
      contextBefore: payload['context_before'] as String?,
      contextAfter: payload['context_after'] as String?,
      chapterTitle: payload['chapter_title'] as String?,
      chapterIndex: payload['chapter_index'] as int?,
      cfi: payload['cfi'] as String?,
    );
  }
  void _captureHighlightSilently({
    required WidgetRef ref,
    required HighlightCreateModel highlight,
  }) {
    final HighlightApi api = ref.read(highlightApiProvider);
    unawaited(
      api.createHighlight(highlight).then((_) {
        ref.read(vaultSyncNotifierProvider).onHighlightCaptured();
      }),
    );
  }

  BookApiModel? _bookMetadata() {
    if (widget.bookExtra is BookApiModel) {
      return widget.bookExtra as BookApiModel;
    }
    return _resolvedBook;
  }

  Future<void> _resolveBookMetadata(String userId) async {
    if (widget.bookExtra is BookApiModel) {
      _resolvedBook = widget.bookExtra as BookApiModel;
      return;
    }
    if (_resolvedBook != null) {
      return;
    }
    try {
      final List<BookApiModel> books = await BookApi().listBooks(userId);
      for (final BookApiModel book in books) {
        if (book.id == widget.bookId) {
          _resolvedBook = book;
          return;
        }
      }
    } catch (_) {
      // Non-fatal: chapter index falls back to a single placeholder chapter.
    }
  }

  List<BookChapterApiModel> _bookChapters() {
    final BookApiModel? book = _bookMetadata();
    final List<BookChapterApiModel> chapters = List<BookChapterApiModel>.from(
      book?.chapters ?? <BookChapterApiModel>[],
    );
    chapters.sort(
      (BookChapterApiModel a, BookChapterApiModel b) =>
          a.chapterIndex.compareTo(b.chapterIndex),
    );
    if (chapters.isEmpty) {
      return const <BookChapterApiModel>[
        BookChapterApiModel(chapterIndex: 0, title: 'Chapter 1'),
      ];
    }
    return chapters;
  }
  double _calculateProgressPercent(int chapterIndex) {
    final int total = _bookChapters().length;
    if (total <= 0) return 0;
    return (((chapterIndex + 1) / total) * 100).clamp(0, 100).toDouble();
  }
  String _buildCurrentReaderHtml(BuildContext context) {
    return _buildReaderHtml(
      chapterHtml: _chapterHtml ?? '',
      chapterTitle: _activeChapterTitle ?? 'Chapter ${_activeChapterIndex + 1}',
      textColorHex: _readerTextColorHex(context),
      backgroundColorHex: _readerBackgroundColorHex(context),
      useOriginalFont: ref.read(readerPreferencesProvider).useOriginalFont,
      fontSize: _readerFontSize,
    );
  }

  Future<void> _syncChapterToWebView() async {
    final InAppWebViewController? controller = _webViewController;
    if (!mounted || controller == null || _chapterHtml == null) {
      return;
    }
    _dismissDictHint();
    await controller.loadData(
      data: _buildCurrentReaderHtml(context),
      mimeType: 'text/html',
      encoding: 'utf-8',
      baseUrl: WebUri(BookApi.baseUrl),
    );
    await _applyReaderFontSize();
  }

  Future<void> _initializeReader() async {
    final String? userId = ref.read(sessionUserIdProvider);
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _isChapterLoading = false;
        _chapterLoadError = 'Please sign in to open the reader.';
      });
      return;
    }
    await _resolveBookMetadata(userId);
    if (!mounted) return;
    final BookApi api = BookApi();
    final ReadingProgressModel? progress = await api.getReadingProgress(
      userId: userId,
      bookId: widget.bookId,
    );
    if (!mounted) return;
    _activeChapterIndex = progress?.chapterIndex ?? 0;
    _progressPercent = progress?.progressPercent ??
        _calculateProgressPercent(_activeChapterIndex);
    await _loadChapterContent(
      chapterIndex: _activeChapterIndex,
      persistProgress: false,
    );
  }
  Future<void> _loadChapterContent({
    required int chapterIndex,
    required bool persistProgress,
  }) async {
    final String? userId = ref.read(sessionUserIdProvider);
    if (userId == null) return;

    final BookChapterContentModel? cached = _chapterCache[chapterIndex];
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _activeChapterIndex = chapterIndex;
        _activeChapterTitle = cached.chapterTitle ?? 'Chapter ${chapterIndex + 1}';
        _chapterHtml = cached.contentHtml;
        _progressPercent = _calculateProgressPercent(chapterIndex);
        _isChapterLoading = false;
        _chapterLoadError = null;
      });
      if (persistProgress) {
        await ref.read(readerControllerProvider(widget.bookId).notifier).saveProgress(
              chapterIndex: chapterIndex,
              chapterTitle: _activeChapterTitle,
              progressPercent: _progressPercent,
            );
      }
      await _syncChapterToWebView();
      _preloadAdjacentChapters(userId);
      return;
    }

    if (mounted) {
      setState(() {
        _isChapterLoading = true;
        _chapterLoadError = null;
      });
    }
    final BookApi api = BookApi();
    try {
      final BookChapterContentModel chapter = await api.getChapterContent(
        userId: userId,
        bookId: widget.bookId,
        chapterIndex: chapterIndex,
      );
      if (!mounted) return;
      _chapterCache[chapterIndex] = chapter;
      setState(() {
        _activeChapterIndex = chapterIndex;
        _activeChapterTitle = chapter.chapterTitle ?? 'Chapter ${chapterIndex + 1}';
        _chapterHtml = chapter.contentHtml;
        _progressPercent = _calculateProgressPercent(chapterIndex);
        _isChapterLoading = false;
      });
      if (persistProgress) {
        await ref.read(readerControllerProvider(widget.bookId).notifier).saveProgress(
              chapterIndex: chapterIndex,
              chapterTitle: _activeChapterTitle,
              progressPercent: _progressPercent,
            );
      }
      await _syncChapterToWebView();
      _preloadAdjacentChapters(userId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isChapterLoading = false;
        _chapterLoadError = 'Unable to load chapter content.';
      });
    }
  }

  void _preloadAdjacentChapters(String userId) {
    final List<BookChapterApiModel> chapters = _bookChapters();
    final int total = chapters.length;
    for (final int offset in [-1, 1]) {
      final int idx = _activeChapterIndex + offset;
      if (idx >= 0 && idx < total && !_chapterCache.containsKey(idx)) {
        unawaited(_fetchAndCacheChapter(userId, idx));
      }
    }
  }

  Future<void> _fetchAndCacheChapter(String userId, int chapterIndex) async {
    try {
      final BookChapterContentModel chapter = await BookApi().getChapterContent(
        userId: userId,
        bookId: widget.bookId,
        chapterIndex: chapterIndex,
      );
      _chapterCache[chapterIndex] = chapter;
    } catch (_) {
      // Silently ignore preload failures — user can still navigate manually.
    }
  }
  Future<void> _applyReaderFontSize() async {
    final InAppWebViewController? controller = _webViewController;
    if (controller == null) return;
    await controller.evaluateJavascript(
      source:
          "document.body.style.fontSize='${_readerFontSize.toStringAsFixed(0)}px';",
    );
  }
  Future<void> _changeReaderFontSize(double delta) async {
    final double nextFontSize =
        (_readerFontSize + delta).clamp(_minReaderFontSize, _maxReaderFontSize);
    if (nextFontSize == _readerFontSize) return;
    setState(() {
      _readerFontSize = nextFontSize;
    });
    await _syncChapterToWebView();
  }
  String _readerTextColorHex(BuildContext context) {
    final Color textColor = Theme.of(context).colorScheme.onSurface;
    return '#${textColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }
  String _readerBackgroundColorHex(BuildContext context) {
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return '#${backgroundColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }
  Future<void> _goToPreviousChapter() async {
    if (_activeChapterIndex <= 0) return;
    await _loadChapterContent(
      chapterIndex: _activeChapterIndex - 1,
      persistProgress: true,
    );
  }
  Future<void> _goToNextChapter() async {
    final int lastIndex = _bookChapters().length - 1;
    if (_activeChapterIndex >= lastIndex) return;
    await _loadChapterContent(
      chapterIndex: _activeChapterIndex + 1,
      persistProgress: true,
    );
  }

  String _buildReaderHtml({
    required String chapterHtml,
    required String chapterTitle,
    required String textColorHex,
    required String backgroundColorHex,
    required bool useOriginalFont,
    required double fontSize,
  }) {
    final String escapedHtml = jsonEncode(chapterHtml);
    final String escapedTitle = jsonEncode(chapterTitle);
    final String baseHref = BookApi.baseUrl.endsWith('/')
        ? BookApi.baseUrl
        : '${BookApi.baseUrl}/';
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"/>
  <base href="$baseHref"/>
  <style>
    ${useOriginalFont ? '' : "@import url('https://fonts.googleapis.com/css2?family=DynaPuff:wght@400..700&display=swap');"}
    :root {
      color-scheme: light dark;
    }
    html, body {
      margin: 0;
      padding: 0;
      background: $backgroundColorHex !important;
      color: $textColorHex !important;
      font-family: ${useOriginalFont ? "Georgia, 'Times New Roman', serif" : "'DynaPuff', cursive"};
      font-size: ${fontSize.toStringAsFixed(0)}px;
      line-height: 1.7;
      touch-action: manipulation;
      -webkit-text-size-adjust: 100%;
    }
    body {
      padding: 20px;
    }
    #chapter-root {
      touch-action: manipulation;
      -webkit-user-select: none;
      user-select: none;
      -webkit-touch-callout: none;
    }
    #chapter-root, #chapter-root * {
      background: transparent !important;
      color: inherit !important;
      ${!useOriginalFont ? "font-family: 'DynaPuff', cursive !important;" : ''}
    }
    .ghost-captured { animation: ghostGlow 420ms ease-out; background: rgba(255, 238, 186, 0.78); border-radius: 4px; }
    @keyframes ghostGlow {
      0% { background: rgba(255, 238, 186, 0.95); }
      100% { background: rgba(255, 238, 186, 0.0); }
    }
  </style>
</head>
<body>
  <main id="chapter-root"></main>
  <script>
    const chapterHtml = $escapedHtml;
    const chapterTitle = $escapedTitle;
    const isWeb = $kIsWeb;
    const readerGestureState = { suppressTapUntil: 0 };
    document.getElementById('chapter-root').innerHTML = chapterHtml;

    function postToFlutter(handlerName, payload) {
      const bridgePayload = JSON.stringify({ handler: handlerName, payload: payload || {} });
      if (!isWeb && window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        try {
          window.flutter_inappwebview.callHandler(handlerName, payload);
          return;
        } catch (e) {}
      }
      if (isWeb) {
        try { window.parent.postMessage('$_webBridgeConsolePrefix' + bridgePayload, '*'); } catch (_) {}
      }
      console.log('$_webBridgeConsolePrefix' + bridgePayload);
    }

    function cleanSpaces(value) {
      return (value || '').replace(/\\s+/g, ' ').trim();
    }
    function splitSentences(text) {
      return cleanSpaces(text).split(/(?<=[.!?])\\s+/).filter(Boolean);
    }
    function findSentenceContext(word, text) {
      const normalizedWord = word.toLowerCase();
      const sentences = splitSentences(text);
      if (sentences.length === 0) return { sentence: '', before: null, after: null };
      let matchIndex = -1;
      for (let i = 0; i < sentences.length; i++) {
        if (sentences[i].toLowerCase().includes(normalizedWord)) {
          matchIndex = i;
          break;
        }
      }
      if (matchIndex < 0) {
        return { sentence: sentences[0], before: null, after: sentences.length > 1 ? sentences[1] : null };
      }
      return {
        sentence: sentences[matchIndex],
        before: matchIndex > 0 ? sentences[matchIndex - 1] : null,
        after: matchIndex < sentences.length - 1 ? sentences[matchIndex + 1] : null,
      };
    }
    function getCfiFallbackFromRange(range) {
      if (!range) return null;
      const container = range.startContainer;
      let node = container.nodeType === 3 ? container.parentElement : container;
      if (!node) return null;
      const path = [];
      while (node && node !== document.body) {
        let index = 0;
        let sibling = node;
        while (sibling.previousElementSibling) {
          sibling = sibling.previousElementSibling;
          index += 1;
        }
        path.unshift(index);
        node = node.parentElement;
      }
      return 'domcfi(' + path.join('/') + ')';
    }
    function rangeFromPoint(x, y) {
      if (document.caretRangeFromPoint) {
        return document.caretRangeFromPoint(x, y);
      }
      if (document.caretPositionFromPoint) {
        const pos = document.caretPositionFromPoint(x, y);
        if (!pos || !pos.offsetNode) return null;
        const r = document.createRange();
        try {
          const max = (pos.offsetNode.textContent || '').length;
          const off = Math.min(Math.max(0, pos.offset), max);
          r.setStart(pos.offsetNode, off);
          r.setEnd(pos.offsetNode, off);
        } catch (e) {
          return null;
        }
        return r;
      }
      return null;
    }
    function isWordChar(c) {
      if (!c) return false;
      if (/[\\s\\u00A0]/.test(c)) return false;
      if (/[.,;:!?'"()\\[\\]{}…—–]/.test(c)) return false;
      return true;
    }
    function extractWordAtCaret(range) {
      if (!range) return null;
      let node = range.startContainer;
      let offset = range.startOffset;
      if (node.nodeType !== 3) return null;
      const text = node.textContent || '';
      if (text.length === 0) return null;
      offset = Math.min(Math.max(0, offset), text.length);
      if (offset < text.length && !isWordChar(text[offset]) && offset > 0) {
        offset -= 1;
      }
      let i = offset;
      while (i > 0 && isWordChar(text[i - 1])) i--;
      let j = offset;
      while (j < text.length && isWordChar(text[j])) j++;
      const word = cleanSpaces(text.slice(i, j));
      if (!word || word.length > 64) return null;
      return { word: word, textNode: node, glowParent: node.parentElement };
    }
    function sendGhostCapture(word, chapterPlainText, glowParent, cfi) {
      const context = findSentenceContext(word, chapterPlainText);
      if (glowParent) {
        glowParent.classList.add('ghost-captured');
        setTimeout(function() { glowParent.classList.remove('ghost-captured'); }, 450);
      }
      const payload = {
        target_word: word,
        context_sentence: context.sentence || chapterPlainText.slice(0, 500),
        context_before: context.before,
        context_after: context.after,
        chapter_title: chapterTitle,
        chapter_index: $_activeChapterIndex,
        cfi: cfi,
      };
      postToFlutter('$_ghostCaptureHandlerName', payload);
    }
    function sendDictionaryHint(word, clientX, clientY) {
      postToFlutter('$_dictionaryHintHandlerName', {
        target_word: word,
        client_x: clientX,
        client_y: clientY,
      });
    }
    function hintWordAt(clientX, clientY) {
      const root = document.getElementById('chapter-root');
      if (!root) return;
      const range = rangeFromPoint(clientX, clientY);
      if (!range) return;
      const extracted = extractWordAtCaret(range);
      if (!extracted) return;
      sendDictionaryHint(extracted.word, clientX, clientY);
    }
    (function attachLongPressGhost() {
      const root = document.getElementById('chapter-root');
      if (!root) return;
      const HOLD_MS = 480;
      const MOVE_MAX = 14;
      let timer = null;
      let startX = 0;
      let startY = 0;
      let downState = null;
      function clearTimer() {
        if (timer) { clearTimeout(timer); timer = null; }
      }
      root.addEventListener('pointerdown', function(e) {
        if (e.pointerType === 'mouse' && e.button !== 0) return;
        clearTimer();
        startX = e.clientX;
        startY = e.clientY;
        const range = rangeFromPoint(e.clientX, e.clientY);
        const extracted = extractWordAtCaret(range);
        if (!extracted) { downState = null; return; }
        downState = { word: extracted.word, glowParent: extracted.glowParent, range: range, x: e.clientX, y: e.clientY };
        timer = setTimeout(function() {
          timer = null;
          const st = downState;
          if (!st) return;
          readerGestureState.suppressTapUntil = Date.now() + 600;
          sendDictionaryHint(st.word, st.x, st.y);
          downState = null;
        }, HOLD_MS);
      }, { passive: true });
      root.addEventListener('pointermove', function(e) {
        if (!timer) return;
        if (Math.hypot(e.clientX - startX, e.clientY - startY) > MOVE_MAX) clearTimer();
      }, { passive: true });
      root.addEventListener('pointerup', function() { clearTimer(); downState = null; }, { passive: true });
      root.addEventListener('pointercancel', function() { clearTimer(); downState = null; }, { passive: true });
    })();
    (function attachDoubleTapCapture() {
      const root = document.getElementById('chapter-root');
      if (!root) return;
      let lastTapTime = 0;
      let lastTapX = 0;
      let lastTapY = 0;
      const DOUBLE_MS = 380;
      const DOUBLE_DIST = 48;
      function captureWordAt(x, y) {
        const range = rangeFromPoint(x, y);
        if (!range) return;
        const extracted = extractWordAtCaret(range);
        if (!extracted) return;
        const chapterPlainText = cleanSpaces(root.innerText || '');
        if (!chapterPlainText) return;
        sendGhostCapture(extracted.word, chapterPlainText, extracted.glowParent, getCfiFallbackFromRange(range));
      }
      function handleTapAt(x, y, preventDefaultFn) {
        const now = Date.now();
        if (now < readerGestureState.suppressTapUntil) {
          return;
        }
        if (now - lastTapTime < DOUBLE_MS &&
            Math.hypot(x - lastTapX, y - lastTapY) < DOUBLE_DIST) {
          lastTapTime = 0;
          if (preventDefaultFn) preventDefaultFn();
          captureWordAt(x, y);
          readerGestureState.suppressTapUntil = Date.now() + 600;
        } else {
          lastTapTime = now;
          lastTapX = x;
          lastTapY = y;
        }
      }
      root.addEventListener('pointerup', function(e) {
        if (e.pointerType === 'mouse' && e.button !== 0) return;
        handleTapAt(e.clientX, e.clientY, function() { e.preventDefault(); });
      });
      root.addEventListener('dblclick', function(e) {
        e.preventDefault();
        if (Date.now() < readerGestureState.suppressTapUntil) return;
        captureWordAt(e.clientX, e.clientY);
      });
      root.addEventListener('contextmenu', function(e) { e.preventDefault(); });
    })();
    (function attachScrollDismissHint() {
      function postDismiss() {
        postToFlutter('$_dictionaryDismissHandlerName', {});
      }
      window.addEventListener('scroll', postDismiss, true);
      document.addEventListener('scroll', postDismiss, true);
    })();
    (function attachChapterLinkInterception() {
      if (!isWeb) return;
      const root = document.getElementById('chapter-root');
      if (!root) return;
      root.addEventListener('click', function(e) {
        const link = e.target.closest('a');
        if (!link) return;
        const href = link.getAttribute('href');
        if (!href) return;
        const resMarker = '/resources/';
        const resIdx = href.indexOf(resMarker);
        if (resIdx < 0) return;
        e.preventDefault();
        let targetHref = href.substring(resIdx + resMarker.length);
        const queryIdx = targetHref.indexOf('?');
        if (queryIdx >= 0) targetHref = targetHref.substring(0, queryIdx);
        postToFlutter('$_chapterNavigationHandlerName', { href: targetHref });
      });
    })();
  </script>
</body>
</html>
''';
  }

  void _showReaderIndexSheet(BuildContext context) {
    final List<BookChapterApiModel> chapters = _bookChapters();
    setState(() => _isIndexSheetOpen = true);
    disableWebviewPointerEvents();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (BuildContext context, ScrollController scrollController) {
              return ListView.builder(
                controller: scrollController,
                itemCount: chapters.length,
                itemBuilder: (BuildContext context, int index) {
                  final BookChapterApiModel chapter = chapters[index];
                  final String title =
                      chapter.title ?? 'Chapter ${chapter.chapterIndex + 1}';
                  final bool isActive = chapter.chapterIndex == _activeChapterIndex;
                  return ListTile(
                    leading: const Icon(Icons.menu_book_rounded),
                    title: Text(title),
                    trailing: isActive ? const Icon(Icons.check_circle_rounded) : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      unawaited(
                        _loadChapterContent(
                          chapterIndex: chapter.chapterIndex,
                          persistProgress: true,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      enableWebviewPointerEvents();
      if (mounted) {
        setState(() => _isIndexSheetOpen = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    
    final book = _bookMetadata();
    final title = book?.title ?? 'Unknown Book';

    final progressAsync = ref.watch(readerControllerProvider(widget.bookId));
    final readerPrefs = ref.watch(readerPreferencesProvider);

    ref.listen<ReaderPreferences>(readerPreferencesProvider, (prev, next) {
      if (prev != null && prev.useOriginalFont != next.useOriginalFont && _chapterHtml != null) {
        _reloadChapterForFontChange();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.outline))),
              child: Row(children: [
                IconButton(onPressed: () => context.go('/shelf'), icon: const Icon(Icons.arrow_back_rounded)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.headlineMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (progressAsync.isLoading)
                        Text('Loading progress...', style: theme.textTheme.bodyLarge?.copyWith(color: muted))
                      else
                        Text(_activeChapterTitle ?? 'Chapter ${_activeChapterIndex + 1}', style: theme.textTheme.bodyLarge?.copyWith(color: muted)),
                    ],
                  ),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    onPressed: () => _showReaderIndexSheet(context),
                    icon: const Icon(Icons.list_rounded, size: 28),
                    tooltip: 'Open chapter index',
                  ),
                  IconButton(
                    onPressed: () => context.push('/vault?bookId=${widget.bookId}'),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const FaIcon(FontAwesomeIcons.gem, size: 28),
                        Consumer(
                          builder: (context, ref, child) {
                            final countAsync = ref.watch(bookVaultCountProvider(widget.bookId));
                            final count = countAsync.valueOrNull ?? 0;
                            if (count == 0) return const SizedBox.shrink();
                            return Positioned(
                              right: -8,
                              top: -8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF73D8B4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    tooltip: 'Open this book vault',
                  ),
                ]),
              ]),
            ),
            Expanded(
              child: _isChapterLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _chapterLoadError != null
                      ? Center(child: Text(_chapterLoadError!))
                      : Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring: _isIndexSheetOpen,
                                child: InAppWebView(
                                key: ValueKey<String>('reader-${widget.bookId}'),
                                initialData: InAppWebViewInitialData(
                                  data: _buildCurrentReaderHtml(context),
                                  mimeType: 'text/html',
                                  encoding: 'utf-8',
                                  baseUrl: WebUri(BookApi.baseUrl),
                                ),
                                initialSettings: InAppWebViewSettings(
                                  javaScriptEnabled: true,
                                  disableContextMenu: true,
                                  transparentBackground: true,
                                ),
                                onWebViewCreated: (InAppWebViewController controller) {
                                  _webViewController = controller;
                                  controller.addJavaScriptHandler(
                                    handlerName: _ghostCaptureHandlerName,
                                    callback: (List<dynamic> args) {
                                      if (args.isEmpty) {
                                        return;
                                      }
                                      final dynamic firstArg = args.first;
                                      if (firstArg is! Map) {
                                        return;
                                      }
                                      _handleGhostCapturePayload(
                                        Map<String, dynamic>.from(firstArg),
                                      );
                                    },
                                  );
                                  controller.addJavaScriptHandler(
                                    handlerName: _dictionaryHintHandlerName,
                                    callback: (List<dynamic> args) {
                                      if (args.isEmpty) {
                                        return;
                                      }
                                      final dynamic firstArg = args.first;
                                      if (firstArg is! Map) {
                                        return;
                                      }
                                      final Map<String, dynamic> payload =
                                          Map<String, dynamic>.from(firstArg);
                                      unawaited(_handleDictionaryHintPayload(payload));
                                    },
                                  );
                                  controller.addJavaScriptHandler(
                                    handlerName: _dictionaryDismissHandlerName,
                                    callback: (_) {
                                      _dismissDictHint();
                                    },
                                  );
                                  controller.addJavaScriptHandler(
                                    handlerName: _chapterNavigationHandlerName,
                                    callback: (List<dynamic> args) {
                                      if (args.isEmpty) {
                                        return;
                                      }
                                      final dynamic firstArg = args.first;
                                      if (firstArg is! Map) {
                                        return;
                                      }
                                      _handleChapterNavigationPayload(
                                        Map<String, dynamic>.from(firstArg),
                                      );
                                    },
                                  );
                                  unawaited(_applyReaderFontSize());
                                },
                                onConsoleMessage: (_, ConsoleMessage consoleMessage) {
                                  _handleReaderBridgeConsoleMessage(consoleMessage.message);
                                },
                                onLoadStop: (_, __) {
                                  unawaited(_applyReaderFontSize());
                                },
                                shouldOverrideUrlLoading: (controller, navigationAction) async {
                                  final uri = navigationAction.request.url;
                                  if (uri == null) return NavigationActionPolicy.ALLOW;

                                  final String urlPath = uri.path;
                                  const String resMarker = '/resources/';
                                  final int resIdx = urlPath.indexOf(resMarker);
                                  if (resIdx < 0) return NavigationActionPolicy.ALLOW;

                                  final String targetHref = urlPath.substring(resIdx + resMarker.length);
                                  if (targetHref.isEmpty) return NavigationActionPolicy.ALLOW;

                                  final List<BookChapterApiModel> chapters = _bookChapters();
                                  for (final BookChapterApiModel ch in chapters) {
                                    if (ch.href != null && ch.href == targetHref) {
                                      if (!mounted) return NavigationActionPolicy.CANCEL;
                                      await _loadChapterContent(
                                        chapterIndex: ch.chapterIndex,
                                        persistProgress: true,
                                      );
                                      return NavigationActionPolicy.CANCEL;
                                    }
                                  }
                                  return NavigationActionPolicy.ALLOW;
                                },
                               ),
                              ),
                             ),
                            if (_dictHint != null)
                              Positioned(
                                left: 12,
                                right: 12,
                                top: math.min(
                                  math.max(8, _dictHint!.anchorY - 72),
                                  320,
                                ),
                                child: Material(
                                  elevation: 6,
                                  borderRadius: BorderRadius.circular(12),
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: Text(
                                                _dictHint!.word,
                                                style: theme.textTheme.titleMedium,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: _dismissDictHint,
                                              icon: const Icon(Icons.close_rounded),
                                              tooltip: 'Dismiss',
                                            ),
                                          ],
                                        ),
                                        if (_dictHint!.loading)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                            child: Center(
                                              child: SizedBox(
                                                width: 28,
                                                height: 28,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            ),
                                          )
                                        else
                                          Text(
                                            _dictHint!.body,
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.colorScheme.outline))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => unawaited(_changeReaderFontSize(-1)),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Text('${_readerFontSize.toStringAsFixed(0)}px', style: theme.textTheme.bodyLarge),
                    IconButton(
                      onPressed: () => unawaited(_changeReaderFontSize(1)),
                      icon: const Icon(Icons.add_rounded),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => ref.read(readerPreferencesProvider.notifier).toggleUseOriginalFont(),
                      icon: Icon(
                        readerPrefs.useOriginalFont ? Icons.font_download_outlined : Icons.font_download,
                        size: 20,
                      ),
                      tooltip: readerPrefs.useOriginalFont ? 'Use app font' : 'Use original book font',
                    ),
                  ],
                ),
                Text('${_progressPercent.toStringAsFixed(1)}%', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 46 / 2)),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => unawaited(_goToPreviousChapter()),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    IconButton(
                      onPressed: () => unawaited(_goToNextChapter()),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderDictHint {
  const _ReaderDictHint({
    required this.word,
    required this.anchorY,
    required this.loading,
    required this.body,
  });

  final String word;
  final double anchorY;
  final bool loading;
  final String body;
}
