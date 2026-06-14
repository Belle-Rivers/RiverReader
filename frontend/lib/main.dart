import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/error/error_logger.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/games/application/game_backfill_provider.dart';
import 'features/games/data/game_api.dart';
import 'features/vault/data/highlight_api.dart';
import 'features/settings/application/backup_autosave_provider.dart';

void main() {
  runZonedGuarded<void>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (FlutterErrorDetails details) {
        ErrorLogger.logFatal('Flutter framework error', details.exception, details.stack);
      };
      
      // Attempt to sync any offline highlights right away, then queue AI game generation.
      try {
        final Set<String> syncedUserIds = await HighlightApi().syncOfflineHighlights();
        final GameApi gameApi = GameApi();
        for (final String userId in syncedUserIds) {
          try {
            await gameApi.triggerBackfill(userId);
          } catch (_) {
            // ignore per-user backfill errors on startup
          }
        }
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
    ref.watch(gameBackfillWorkerProvider);
    ref.watch(backupAutoExportProvider);

    return MaterialApp.router(
      title: 'River Reader',
      theme: themeMode.themeData,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
