import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/error/error_logger.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/current_user_provider.dart';
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

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedUserId = prefs.getString('session_user_id');

      runApp(
        ProviderScope(
          overrides: [
            if (savedUserId != null)
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
      builder: (context, child) {
        if (!kIsWeb) return child!;
        final width = MediaQuery.of(context).size.width;
        if (width < 768) return child!;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: SizedBox(width: 900, child: child),
          ),
        );
      },
    );
  }
}
