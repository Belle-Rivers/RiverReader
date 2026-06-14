import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/file_storage_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/river_ui.dart';
import '../../auth/application/current_user_provider.dart';
import '../../auth/data/registration_api.dart';
import '../../games/application/game_decks_provider.dart';
import '../../games/application/game_session_controller.dart';
import '../../home/application/home_provider.dart';
import '../../reader/controllers/reader_preferences_provider.dart';
import '../../vault/application/vault_provider.dart';
import '../application/backup_autosave_provider.dart';

const List<String> _securityQuestions = <String>[
  'What is the name of the place where you feel most at home?',
  'What book or story made a lasting impression on you?',
  'What was the first city you remember visiting?',
];

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _recoveryFormKey = GlobalKey<FormState>();
  final _securityAnswerController = TextEditingController();
  final _profileApi = RegistrationApi();
  bool _savingRecovery = false;
  bool _exporting = false;
  bool _importing = false;
  String? _selectedQuestion;
  String? _feedback;

  @override
  void dispose() {
    _securityAnswerController.dispose();
    super.dispose();
  }

  Future<void> _saveRecoveryQuestion() async {
    final profile = await ref.read(currentUserProfileProvider.future);
    final userId = ref.read(sessionUserIdProvider);
    if (profile == null || userId == null) return;
    if (!_recoveryFormKey.currentState!.validate()) return;

    setState(() {
      _savingRecovery = true;
      _feedback = null;
    });
    try {
      await _profileApi.updateUserProfile(
        userId,
        UserProfileUpdateRequest(
          securityQuestion: _selectedQuestion ?? profile.securityQuestion,
          securityAnswer: _securityAnswerController.text,
        ),
      );
      if (mounted) {
        setState(() {
          _feedback = 'Security question saved.';
          _securityAnswerController.clear();
        });
      }
      HapticFeedback.mediumImpact();
      ref.invalidate(currentUserProfileProvider);
    } on RegistrationApiException catch (e) {
      setState(() => _feedback = e.message);
    } finally {
      if (mounted) setState(() => _savingRecovery = false);
    }
  }

  Future<void> _exportNow() async {
    final userId = ref.read(sessionUserIdProvider);
    if (userId == null) return;
    setState(() {
      _exporting = true;
      _feedback = null;
    });
    try {
      final savedPath = await ref.read(backupAutoExportProvider).exportNow();
      if (mounted && savedPath != null) {
        setState(() => _feedback = 'Export saved to $savedPath');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importBackup() async {
    setState(() {
      _importing = true;
      _feedback = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.single;
      if (file == null) return;
      final contents = file.bytes != null
          ? String.fromCharCodes(file.bytes!)
          : file.path != null
              ? await FileStorageManager.readTextFile(file.path!)
              : null;
      if (contents == null) return;
      final response = await ref.read(backupAutoExportProvider).importFromText(contents);
      final user = response['user'] as Map<String, dynamic>;
      final userId = user['id'] as String;
      ref.read(sessionUserIdProvider.notifier).setUserId(userId);
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(homeSummaryProvider);
      ref.invalidate(vaultItemsProvider);
      ref.invalidate(gameDecksProvider);
      ref.read(gameApiProvider).triggerBackfill(userId);
      if (mounted) setState(() => _feedback = 'Imported backup for ${user['email']}');
    } catch (err) {
      if (mounted) setState(() => _feedback = 'Import failed: $err');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appThemeNotifierProvider).mode;
    final notifier = ref.read(appThemeNotifierProvider.notifier);
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);

    return RiverScaffold(
      title: 'Settings',
      tab: RiverTab.home,
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      showSettings: false,
      trailing: const SizedBox.shrink(),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('THEME', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _themeCard(
                context,
                selected: mode == AppThemeMode.sunlight,
                name: 'Sunlight',
                icon: Icons.wb_sunny_outlined,
                colors: const [Color(0xFFE9ECC7), Color(0xFF80DDB9)],
                onTap: () => notifier.setMode(AppThemeMode.sunlight),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _themeCard(
                context,
                selected: mode == AppThemeMode.midnight,
                name: 'Midnight',
                icon: Icons.nightlight_round,
                colors: const [Color(0xFF131D35), Color(0xFF4E947D)],
                onTap: () => notifier.setMode(AppThemeMode.midnight),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          Text('READING', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Consumer(
            builder: (context, ref, child) {
              final prefs = ref.watch(readerPreferencesProvider);
              return SwitchListTile(
                title: const Text('Use original book font', style: TextStyle(fontSize: 18)),
                subtitle: Text(
                  prefs.useOriginalFont ? 'Showing serif font from the book' : 'Showing app font (DynaPuff)',
                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
                ),
                value: prefs.useOriginalFont,
                onChanged: (_) => ref.read(readerPreferencesProvider.notifier).toggleUseOriginalFont(),
                activeThumbColor: AppColors.mint,
                contentPadding: EdgeInsets.zero,
              );
            },
          ),
          const SizedBox(height: 24),
          Text('ACCOUNT', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          profileAsync.when(
            data: (profile) => RiverCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile?.displayName ?? (profile != null ? 'Scholar' : 'Not logged in'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(profile?.email ?? 'No active session', style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Text('Error loading profile: $err'),
          ),
          const SizedBox(height: 20),
          Text('RECOVERY', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          profileAsync.when(
            data: (profile) {
              final currentQuestion = _selectedQuestion ?? profile?.securityQuestion;
              final questionOptions = <String>[
                ..._securityQuestions,
                if (currentQuestion != null && currentQuestion.isNotEmpty && !_securityQuestions.contains(currentQuestion))
                  currentQuestion,
              ];
              return RiverCard(
                child: Form(
                  key: _recoveryFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: currentQuestion,
                        items: questionOptions
                            .map(
                              (question) => DropdownMenuItem<String>(
                                value: question,
                                child: Text(question, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _selectedQuestion = value),
                        decoration: const InputDecoration(labelText: 'Security question'),
                        validator: (value) => (value ?? '').trim().isEmpty ? 'Pick a question' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _securityAnswerController,
                        decoration: const InputDecoration(labelText: 'Security answer'),
                        validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _savingRecovery ? null : _saveRecoveryQuestion,
                        child: Text(_savingRecovery ? 'Saving…' : 'Save recovery answer'),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          Text('BACKUP', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          RiverCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Export and import your data as a single bundle.', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exporting ? null : _exportNow,
                        icon: const Icon(Icons.download_outlined),
                        label: Text(_exporting ? 'Exporting…' : 'Export now'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _importing ? null : _importBackup,
                        icon: const Icon(Icons.upload_outlined),
                        label: Text(_importing ? 'Importing…' : 'Import backup'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            Text(_feedback!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              ref.read(sessionUserIdProvider.notifier).clearUserId();
              context.go('/register?mode=signin');
            },
            child: Text('  Sign out', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20, color: Colors.redAccent)),
          ),
          const SizedBox(height: 70),
          Text('River Reader · v0.1 prototype', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _themeCard(
    BuildContext context, {
    required bool selected,
    required String name,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? AppColors.mint : Theme.of(context).colorScheme.outline, width: selected ? 3 : 1.5),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: colors))),
          const SizedBox(height: 8),
          Row(children: [Icon(icon), const SizedBox(width: 8), Expanded(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis))]),
        ]),
      ),
    );
  }
}
