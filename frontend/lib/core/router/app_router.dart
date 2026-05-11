import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/games/presentation/games_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/library/presentation/library_shelf_page.dart';
import '../../features/reader/presentation/reader_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/vault/presentation/vault_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => const HomePage(),
      ),
      GoRoute(
        path: '/register',
        builder: (BuildContext context, GoRouterState state) {
          final String mode = state.uri.queryParameters['mode'] ?? 'create';
          return RegisterPage(initialMode: mode == 'signin' ? RegisterMode.signIn : RegisterMode.create);
        },
      ),
      GoRoute(
        path: '/shelf',
        builder: (BuildContext context, GoRouterState state) => const LibraryShelfPage(),
      ),
      GoRoute(
        path: '/reader',
        builder: (BuildContext context, GoRouterState state) => const ReaderPage(),
      ),
      GoRoute(
        path: '/vault',
        builder: (BuildContext context, GoRouterState state) => const VaultPage(),
      ),
      GoRoute(
        path: '/games',
        builder: (BuildContext context, GoRouterState state) => const GamesPage(),
      ),
    ],
  );
});
