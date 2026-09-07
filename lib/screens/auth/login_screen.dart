import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    if (!_formKey.currentState!.validate()) return;
    await app.signIn(_emailCtrl.text, _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final savedAccounts = app.savedAccounts;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(18)),
                      child: Icon(Icons.emoji_events, color: AppColors.gold, size: 30),
                    ),
                    const SizedBox(height: 20),
                    Text('Podium', style: dispFont(size: 30, weight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.6)),
                    const SizedBox(height: 4),
                    Text('Les scores et classements entre amis.', style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut)),
                    const SizedBox(height: 32),
                    _field(label: 'E-mail', controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _field(label: 'Mot de passe', controller: _passCtrl, obscure: true),
                    if (app.flowError != null) ...[
                      const SizedBox(height: 12),
                      Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
                    ],
                    const SizedBox(height: 24),
                    PrimaryButton(label: 'Se connecter', loading: app.busy, onPressed: () => _submit(app)),
                    if (savedAccounts.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      Text('Comptes enregistrés', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final account in savedAccounts)
                            GestureDetector(
                              onTap: () {
                                _emailCtrl.text = account.email;
                                _emailCtrl.selection = TextSelection.collapsed(offset: account.email.length);
                              },
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  border: Border.all(color: AppColors.line),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Avatar(initial: account.displayName.isNotEmpty ? account.displayName[0].toUpperCase() : '?', color: Color(account.color), size: 28, fontSize: 11),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(account.displayName, style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
                                        Text(account.email, style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut)),
                                      ],
                                    ),
                                    const SizedBox(width: 2),
                                    GestureDetector(
                                      onTap: () => app.removeSavedAccount(account.email),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(Icons.close_rounded, size: 15, color: AppColors.mut),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Touchez un compte pour remplir l’e-mail, ou ✕ pour l’oublier sur cet appareil.', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                    ],
                    const SizedBox(height: 18),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
                        child: Text("Pas encore de compte ? S'inscrire", style: bodyFont(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({required String label, required TextEditingController controller, bool obscure = false, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
        const SizedBox(height: 9),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
          style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
          decoration: appFieldDecoration(),
        ),
      ],
    );
  }
}
