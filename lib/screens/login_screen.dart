import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../state/app_controller.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final success = await widget.controller.login(
      _emailController.text,
      _passwordController.text,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.errorMessage ?? 'Giriş yapılamadı.'),
        ),
      );
    }
  }

  Future<void> _googleLogin() async {
    FocusScope.of(context).unfocus();
    final success = await widget.controller.loginWithGoogle();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.errorMessage ?? 'Google ile giriş yapılamadı.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.controller.isAuthenticating;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.local_parking_rounded,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                Text(
                  'Tekrar hoş geldin',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF17332E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Yakınındaki boş park yerlerini saniyeler içinde bul.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF61726D),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  color: const Color(0xFFEAF5F1),
                  elevation: 0,
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.family_restroom_rounded,
                          color: AppTheme.primary,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Family Link uyumlu: Google ile giriş isteğe bağlıdır. '
                            'Gözetimli hesaplarda ebeveyn onayı gerekebilir; '
                            'e-posta/şifre veya demo ile devam edebilirsiniz.',
                            style: TextStyle(
                              height: 1.35,
                              color: Color(0xFF35534C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty || !email.contains('@')) {
                      return 'Geçerli bir e-posta adresi girin.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  enabled: !busy,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => (value?.length ?? 0) < 6
                      ? 'Şifre en az 6 karakter olmalıdır.'
                      : null,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: busy ? null : _login,
                  icon: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(busy ? 'Giriş yapılıyor...' : 'Giriş Yap'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'veya',
                        style: TextStyle(color: Color(0xFF72817D)),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    foregroundColor: const Color(0xFF17332E),
                    side: const BorderSide(color: Color(0xFFD0D9D6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: busy || !widget.controller.isFirebaseEnabled
                      ? null
                      : _googleLogin,
                  icon: const Text(
                    'G',
                    style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  label: const Text('Google ile Devam Et'),
                ),
                if (!widget.controller.isFirebaseEnabled) ...[
                  const SizedBox(height: 7),
                  const Text(
                    'Google girişi Firebase yapılandırması eklenince etkinleşir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8A6A37), fontSize: 11),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: Color(0xFFB8CEC8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: busy ? null : widget.controller.continueInDemoMode,
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Demo ile Devam Et'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'API kurmadan 81 il örnek verileriyle uygulamayı keşfet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF72817D), fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Hesabın yok mu?'),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RegisterScreen(
                                  controller: widget.controller,
                                ),
                              ),
                            ),
                      child: const Text('Kayıt ol'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
