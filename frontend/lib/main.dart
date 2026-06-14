import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:river_reader_backend/river_reader_backend.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/current_user_provider.dart';
import 'features/auth/application/session_store.dart';
import 'features/games/application/game_backfill_provider.dart';
import 'features/games/data/game_api.dart';
import 'features/vault/data/highlight_api.dart';
import 'features/settings/application/backup_autosave_provider.dart';

Future<void> main() async {
  runZonedGuarded<void>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (FlutterErrorDetails details) {
        ErrorLogger.logFatal('Flutter framework error', details.exception, details.stack);
      };

      final String? savedUserId = await SessionStore.loadUserId();

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

      runApp(
        ProviderScope(
          overrides: savedUserId == null
              ? const <Override>[]
              : <Override>[
                  sessionUserIdProvider.overrideWith(
                    () => SessionUserIdNotifier(initialUserId: savedUserId),
                  ),
                ],
          child: const RiverReaderApp(),
        ),
      );
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
