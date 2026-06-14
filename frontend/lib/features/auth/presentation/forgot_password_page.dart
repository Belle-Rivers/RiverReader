import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../application/auth_providers.dart';
import '../data/registration_api.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _answerController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _question;
  String? _error;
  bool _loadingQuestion = false;
  bool _resetting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _answerController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestion() async {
    final String email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _loadingQuestion = true;
      _error = null;
    });
    try {
      final api = ref.read(registrationApiProvider);
      final response = await api.getRecoveryQuestion(email);
      setState(() => _question = response.securityQuestion);
    } on RegistrationApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingQuestion = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _resetting = true;
      _error = null;
    });
    try {
      final api = ref.read(registrationApiProvider);
      await api.resetPassword(
        ResetPasswordRequest(
          email: _emailController.text.trim(),
          securityAnswer: _answerController.text,
          newPassword: _passwordController.text,
        ),
      );
      HapticFeedback.mediumImpact();
      if (mounted) {
        context.go('/register?mode=signin');
      }
    } on RegistrationApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Unexpected error');
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF040B24) : const Color(0xFFF1F0CC);
    final panel = dark ? const Color(0xFF1C2641) : const Color(0xFFEDF0DC);
    final text = dark ? const Color(0xFFF9F4DA) : const Color(0xFF1D1B16);

    return Scaffold(
      body: Container(
        color: bg,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Center(child: Text('Forgot password', style: RiverFonts.handwritten(size: 36, color: AppColors.mint))),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(24)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(labelText: 'Email'),
                              keyboardType: TextInputType.emailAddress,
                              onFieldSubmitted: (_) => _loadQuestion(),
                              validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _loadingQuestion ? null : _loadQuestion,
                              child: Text(_loadingQuestion ? 'Loading…' : 'Load security question'),
                            ),
                            const SizedBox(height: 18),
                            if (_question != null) ...[
                              Text('Security question', style: TextStyle(color: text.withValues(alpha: .7))),
                              const SizedBox(height: 6),
                              Text(_question!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _answerController,
                                decoration: const InputDecoration(labelText: 'Answer'),
                                validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                decoration: const InputDecoration(labelText: 'New password'),
                                obscureText: true,
                                validator: (value) {
                                  final text = (value ?? '').trim();
                                  if (text.isEmpty) return 'Required';
                                  if (text.length < 8) return 'Min 8 characters';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _resetting ? null : _resetPassword,
                                child: Text(_resetting ? 'Resetting…' : 'Reset password'),
                              ),
                            ],
                            if (_question == null)
                              Text(
                                'Enter your email, then load the question you set in Settings.',
                                style: TextStyle(color: text.withValues(alpha: .72)),
                              ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                            ],
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => context.go('/register?mode=signin'),
                              child: const Text('Back to sign in'),
                            ),
                          ],
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
    );
  }
}
