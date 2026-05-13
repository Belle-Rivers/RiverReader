import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  late RegisterMode _mode;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final preferredLocale = Localizations.localeOf(context).toLanguageTag();
    try {
      final api = ref.read(registrationApiProvider);
      final response = _mode == RegisterMode.create
          ? await api.register(RegistrationRequest(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              displayName: _displayNameController.text.trim().isEmpty ? null : _displayNameController.text.trim(),
              preferredLocale: preferredLocale,
              timezone: DateTime.now().timeZoneName,
            ))
          : await api.login(LoginRequest(email: _emailController.text.trim(), password: _passwordController.text));
      ref.read(sessionUserIdProvider.notifier).setUserId(response.id);
      HapticFeedback.mediumImpact();
      if (mounted) context.go('/');
    } on RegistrationApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Unexpected error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () {
                          ref.read(appThemeNotifierProvider.notifier).setMode(
                                dark ? AppThemeMode.sunlight : AppThemeMode.midnight,
                              );
                        },
                        icon: Icon(dark ? Icons.wb_sunny_outlined : Icons.nightlight_round, color: text),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(child: Image.asset('assets/images/RiverReader_logo.png', width: 210, height: 190, fit: BoxFit.cover)),
                    const SizedBox(height: 2),
                    Center(
                      child: Text(
                        'read in flow.',
                        style: RiverFonts.handwritten(size: 30, color: AppColors.mint),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(28)),
                      child: Row(children: [
                        _seg('Sign in', _mode == RegisterMode.signIn, () => setState(() => _mode = RegisterMode.signIn), panel, text),
                        _seg('Register', _mode == RegisterMode.create, () => setState(() => _mode = RegisterMode.create), panel, text),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    if (_mode == RegisterMode.create) ...[
                      _label('Name', text),
                      _field(_displayNameController, 'Jane Scholar'),
                      const SizedBox(height: 16),
                    ],
                    _label('Email', text),
                    _field(_emailController, 'you@scholar.com'),
                    const SizedBox(height: 16),
                    _label('Password', text),
                    _field(_passwordController, _mode == RegisterMode.create ? 'At least 8 characters' : '••••••••', obscureText: true, isPassword: true),
                    if (_errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent))),
                    const SizedBox(height: 18),
                    ElevatedButton(onPressed: _isSubmitting ? null : _submit, child: Text(_mode == RegisterMode.create ? 'Create account' : 'Sign in')),
                    if (_mode == RegisterMode.signIn) Padding(padding: const EdgeInsets.only(top: 16), child: Text('Forgot password?', textAlign: TextAlign.center, style: TextStyle(color: text.withValues(alpha: .7)))),
                    const SizedBox(height: 28),
                    Text('By continuing you agree to the gentle scholar\'s code. Skip', textAlign: TextAlign.center, style: TextStyle(color: text.withValues(alpha: .65))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _seg(String text, bool active, VoidCallback onTap, Color panel, Color fg) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: active ? Colors.black.withValues(alpha: .28) : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: active ? Colors.transparent : Colors.white.withValues(alpha: .1)),
          ),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: fg.withValues(alpha: active ? 1 : .55), fontSize: 18)),
        ),
      ),
    );
  }

  Widget _label(String t, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: GoogleFonts.newsreader(fontSize: 22, color: color, fontWeight: FontWeight.w700)),
      );

  Widget _field(TextEditingController? c, String h, {bool obscureText = false, bool isPassword = false}) => TextFormField(
        controller: c,
        obscureText: obscureText,
        validator: c == null
            ? null
            : (v) {
                final val = (v ?? '').trim();
                if (val.isEmpty) return 'Required';
                if (isPassword && val.length < 8) return 'Min 8 characters';
                return null;
              },
        decoration: InputDecoration(hintText: h),
      );
}
