import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/application/current_user_provider.dart';
import '../../auth/data/registration_api.dart';
import '../../../core/storage/auto_backup_service.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _attemptAutoRestore().whenComplete(() {
      _timer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) {
          final userId = ref.read(sessionUserIdProvider);
          context.go(userId != null ? '/' : '/register');
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _attemptAutoRestore() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getString('session_user_id');
    if (savedUserId == null) return;

    try {
      await RegistrationApi().getUserProfile(savedUserId);
      return;
    } catch (_) {
      // User not found on backend — it was likely wiped.
    }

    final backupData = await loadBackupFromStorage();
    if (backupData == null || !mounted) return;

    try {
      final Map<String, dynamic> result =
          await RegistrationApi().importUserData(backupData);
      final String restoredUserId =
          (result['user'] as Map<String, dynamic>)['id'] as String;
      ref.read(sessionUserIdProvider.notifier).setUserId(restoredUserId);
      await prefs.setString('session_user_id', restoredUserId);
    } catch (_) {
      // Restore failed — user will land on the register page.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.scaffoldBackgroundColor,
              theme.colorScheme.surface.withValues(alpha: .9),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: .22),
                      blurRadius: 36,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/images/RiverReader_logo.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'read in flow.',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
