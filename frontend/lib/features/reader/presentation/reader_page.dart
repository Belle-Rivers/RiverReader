import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/theme_mode_menu_button.dart';

class ReaderPage extends ConsumerWidget {
  const ReaderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EPUB Reader'),
        actions: const <Widget>[ThemeModeMenuButton()],
      ),
      body: const Center(
        child: Text('Phase 2 will integrate Epub.js via WebView.'),
      ),
    );
  }
}

