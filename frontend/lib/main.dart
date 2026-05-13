import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:river_reader_backend/river_reader_backend.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/vault/data/highlight_api.dart';

void main() {
  runZonedGuarded<void>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (FlutterErrorDetails details) {
        ErrorLogger.logFatal('Flutter framework error', details.exception, details.stack);
      };
      
      // Attempt to sync any offline highlights right away
      try {
        await HighlightApi().syncOfflineHighlights();
      } catch (e) {
        // ignore errors on startup sync
      }
      
      runApp(const ProviderScope(child: RiverReaderApp()));
    },
    (Object error, StackTrace stackTrace) {
      ErrorLogger.logFatal('Uncaught zone error', error, stackTrace);
    },
  );
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
