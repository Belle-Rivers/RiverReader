import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../library/data/book_api.dart';
import '../../vault/data/highlight_api.dart';
import '../../auth/application/current_user_provider.dart';
import '../../vault/application/vault_provider.dart';
import '../controllers/reader_controller.dart';
import '../data/dictionary_api.dart';

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

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_initializeReader);
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

  List<BookChapterApiModel> _bookChapters() {
    final BookApiModel? book = widget.bookExtra is BookApiModel
        ? widget.bookExtra as BookApiModel
        : null;
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isChapterLoading = false;
        _chapterLoadError = 'Unable to load chapter content.';
      });
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
    await _applyReaderFontSize();
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
  }) {
    final String escapedHtml = jsonEncode(chapterHtml);
    final String escapedTitle = jsonEncode(chapterTitle);
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <style>
    :root {
      color-scheme: light dark;
    }
    html, body {
      margin: 0;
      padding: 0;
      background: $backgroundColorHex !important;
      color: $textColorHex !important;
      font-family: serif;
      line-height: 1.7;
    }
    body {
      padding: 20px;
    }
    #chapter-root, #chapter-root * {
      background: transparent !important;
      color: inherit !important;
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
    document.getElementById('chapter-root').innerHTML = chapterHtml;

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
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('$_ghostCaptureHandlerName', payload);
      }
    }
    function sendDictionaryHint(word, clientX, clientY) {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('$_dictionaryHintHandlerName', {
          target_word: word,
          client_x: clientX,
          client_y: clientY,
        });
      }
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
        downState = { word: extracted.word, glowParent: extracted.glowParent, range: range };
        timer = setTimeout(function() {
          timer = null;
          const st = downState;
          if (!st) return;
          const chapterPlainText = cleanSpaces(root.innerText || '');
          if (!chapterPlainText) return;
          sendGhostCapture(st.word, chapterPlainText, st.glowParent, getCfiFallbackFromRange(st.range));
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
    (function attachDoubleTapHint() {
      const root = document.getElementById('chapter-root');
      if (!root) return;
      let lastTapTime = 0;
      let lastTapX = 0;
      let lastTapY = 0;
      const DOUBLE_MS = 380;
      const DOUBLE_DIST = 48;
      root.addEventListener('touchend', function(e) {
        if (e.changedTouches.length !== 1) return;
        const t = e.changedTouches[0];
        const now = Date.now();
        const x = t.clientX;
        const y = t.clientY;
        if (now - lastTapTime < DOUBLE_MS &&
            Math.hypot(x - lastTapX, y - lastTapY) < DOUBLE_DIST) {
          lastTapTime = 0;
          hintWordAt(x, y);
        } else {
          lastTapTime = now;
          lastTapX = x;
          lastTapY = y;
        }
      }, { passive: true });
      root.addEventListener('dblclick', function(e) {
        e.preventDefault();
        hintWordAt(e.clientX, e.clientY);
      });
    })();
    (function attachScrollDismissHint() {
      function postDismiss() {
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('$_dictionaryDismissHandlerName', {});
        }
      }
      window.addEventListener('scroll', postDismiss, true);
      document.addEventListener('scroll', postDismiss, true);
    })();
  </script>
</body>
</html>
''';
  }

  void _showReaderIndexSheet(BuildContext context) {
    final List<BookChapterApiModel> chapters = _bookChapters();
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView.builder(
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final String readerTextHex = _readerTextColorHex(context);
    final String readerBackgroundHex = _readerBackgroundColorHex(context);
    
    final book = widget.bookExtra is BookApiModel ? widget.bookExtra as BookApiModel : null;
    final title = book?.title ?? 'Unknown Book';

    final progressAsync = ref.watch(readerControllerProvider(widget.bookId));

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
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 28),
                        Positioned(
                          right: -3,
                          top: -8,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: const Color(0xFF73D8B4),
                            child: Text(
                              '•',
                              style: theme.textTheme.labelMedium?.copyWith(color: Colors.black),
                            ),
                          ),
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
                              child: InAppWebView(
                                key: ValueKey<int>(_activeChapterIndex),
                                initialData: InAppWebViewInitialData(
                                  data: _buildReaderHtml(
                                    chapterHtml: _chapterHtml ?? '',
                                    chapterTitle: _activeChapterTitle ??
                                        'Chapter ${_activeChapterIndex + 1}',
                                    textColorHex: readerTextHex,
                                    backgroundColorHex: readerBackgroundHex,
                                  ),
                                  mimeType: 'text/html',
                                  encoding: 'utf-8',
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
                                      final String? userId =
                                          ref.read(sessionUserIdProvider);
                                      if (userId == null || args.isEmpty) {
                                        return;
                                      }
                                      final dynamic firstArg = args.first;
                                      if (firstArg is! Map) {
                                        return;
                                      }
                                      final Map<String, dynamic> payload =
                                          Map<String, dynamic>.from(firstArg);
                                      final HighlightCreateModel? highlight =
                                          _buildHighlightFromBridgePayload(
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
                                  unawaited(_applyReaderFontSize());
                                },
                                onLoadStop: (_, __) {
                                  unawaited(_applyReaderFontSize());
                                },
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
