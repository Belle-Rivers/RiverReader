import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:river_reader_backend/river_reader_backend.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runZonedGuarded<void>(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (FlutterErrorDetails details) {
        ErrorLogger.logFatal('Flutter framework error', details.exception, details.stack);
      };
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
