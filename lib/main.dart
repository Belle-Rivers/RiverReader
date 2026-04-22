import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: RiverReaderApp()));
}

class RiverReaderApp extends ConsumerWidget {
  const RiverReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(appThemeNotifierProvider);

    return MaterialApp.router(
      title: 'River Reader',
      theme: themeMode.themeData,
      routerConfig: router,
    );
  }
}
