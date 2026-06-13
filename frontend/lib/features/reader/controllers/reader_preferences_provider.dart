import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kUseOriginalFontKey = 'reader_use_original_font';

final readerPreferencesProvider = NotifierProvider<ReaderPreferencesNotifier, ReaderPreferences>(
  ReaderPreferencesNotifier.new,
);

class ReaderPreferences {
  const ReaderPreferences({required this.useOriginalFont});
  final bool useOriginalFont;

  ReaderPreferences copyWith({bool? useOriginalFont}) {
    return ReaderPreferences(
      useOriginalFont: useOriginalFont ?? this.useOriginalFont,
    );
  }
}

class ReaderPreferencesNotifier extends Notifier<ReaderPreferences> {
  bool _initialized = false;

  @override
  ReaderPreferences build() => const ReaderPreferences(useOriginalFont: false);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    final useOriginal = prefs.getBool(_kUseOriginalFontKey) ?? false;
    state = state.copyWith(useOriginalFont: useOriginal);
  }

  Future<void> toggleUseOriginalFont() async {
    final next = state.copyWith(useOriginalFont: !state.useOriginalFont);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseOriginalFontKey, next.useOriginalFont);
  }
}
