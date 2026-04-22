import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Library Shelf'))),
      ),
      GoRoute(
        path: '/reader',
        builder: (context, state) => const Scaffold(body: Center(child: Text('EPUB Reader'))),
      ),
      GoRoute(
        path: '/vault',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Scholar Vault'))),
      ),
    ],
  );
});
