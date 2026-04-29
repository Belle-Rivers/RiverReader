import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/theme_mode_menu_button.dart';

class VaultPage extends ConsumerWidget {
  const VaultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scholar's Vault"),
        actions: const <Widget>[ThemeModeMenuButton()],
      ),
      body: const Center(
        child: Text('Phase 4 will implement the Vault list + search.'),
      ),
    );
  }
}

