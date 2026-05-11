import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/current_user_provider.dart';
import '../data/registration_api.dart';

enum RegisterMode { create, signIn }

final registrationApiProvider = Provider<RegistrationApi>((ref) => RegistrationApi());

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.initialMode = RegisterMode.create});

  final RegisterMode initialMode;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  late RegisterMode _mode;
  bool _isSubmitting = false;
  String? _errorMessage;
  RegistrationResponse? _success;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _completeSession(RegistrationResponse response) {
    ref.read(sessionUserIdProvider.notifier).setUserId(response.id);
    if (!mounted) {
      return;
    }
    context.go('/');
  }

  Future<void> _submitCreate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _success = null;
    });
    try {
      final RegistrationApi api = ref.read(registrationApiProvider);
      final RegistrationResponse response = await api.register(
        RegistrationRequest(
          username: _usernameController.text.trim(),
          displayName: _displayNameController.text.trim().isEmpty
              ? null
              : _displayNameController.text.trim(),
          preferredLocale: Localizations.localeOf(context).toLanguageTag(),
          timezone: DateTime.now().timeZoneName,
        ),
      );
      HapticFeedback.mediumImpact();
      if (!mounted) {
        return;
      }
      setState(() {
        _success = response;
      });
      _completeSession(response);
    } on RegistrationApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Unexpected error while registering';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitSignIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _success = null;
    });
    try {
      final RegistrationApi api = ref.read(registrationApiProvider);
      final RegistrationResponse response =
          await api.findProfileByUsername(_usernameController.text.trim());
      HapticFeedback.mediumImpact();
      if (!mounted) {
        return;
      }
      setState(() {
        _success = response;
      });
      _completeSession(response);
    } on RegistrationApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Unexpected error while signing in';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_mode == RegisterMode.create) {
      await _submitCreate();
    } else {
      await _submitSignIn();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String title = _mode == RegisterMode.create ? 'Create Profile' : 'Sign In';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _mode == RegisterMode.create
                              ? 'Welcome to River Reader'
                              : 'Welcome back',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _mode == RegisterMode.create
                              ? 'Start by creating your local profile.'
                              : 'Enter the username for an existing profile on this device.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SegmentedButton<RegisterMode>(
                          segments: const <ButtonSegment<RegisterMode>>[
                            ButtonSegment<RegisterMode>(
                              value: RegisterMode.create,
                              label: Text('New profile'),
                              icon: Icon(Icons.person_add_alt_1),
                            ),
                            ButtonSegment<RegisterMode>(
                              value: RegisterMode.signIn,
                              label: Text('Sign in'),
                              icon: Icon(Icons.login),
                            ),
                          ],
                          selected: <RegisterMode>{_mode},
                          onSelectionChanged: (Set<RegisterMode> selection) {
                            setState(() {
                              _mode = selection.first;
                              _errorMessage = null;
                              _success = null;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _usernameController,
                          textInputAction: _mode == RegisterMode.create
                              ? TextInputAction.next
                              : TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            hintText: 'reader_rony',
                          ),
                          validator: (String? value) {
                            final String trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return 'Username is required';
                            }
                            if (trimmed.length > 64) {
                              return 'Maximum 64 characters';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) {
                            if (_isSubmitting) {
                              return;
                            }
                            if (_mode == RegisterMode.signIn) {
                              _submit();
                            }
                          },
                        ),
                        if (_mode == RegisterMode.create) ...<Widget>[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _displayNameController,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Display name (optional)',
                              hintText: 'Rony',
                            ),
                            onFieldSubmitted: (_) {
                              if (!_isSubmitting) {
                                _submit();
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (_success != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _mode == RegisterMode.create
                                  ? 'Created ${_success!.username} • id: ${_success!.id}'
                                  : 'Signed in as ${_success!.username}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: Text(
                              _isSubmitting
                                  ? (_mode == RegisterMode.create ? 'Creating...' : 'Signing in...')
                                  : (_mode == RegisterMode.create ? 'Create Profile' : 'Sign In'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
