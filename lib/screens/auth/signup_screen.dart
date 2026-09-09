import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    if (!_formKey.currentState!.validate()) return;
    await app.signUp(_emailCtrl.text, _passCtrl.text, _nameCtrl.text);
    if (app.currentUser != null && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0, foregroundColor: AppColors.ink),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: FadeSlideIn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Créer un compte', style: dispFont(size: 26, weight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text('Pour rejoindre ou créer vos groupes.', style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut)),
                      const SizedBox(height: 28),
                      _field(label: 'Prénom', controller: _nameCtrl),
                      const SizedBox(height: 16),
                      _field(label: 'E-mail', controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 16),
                      _field(label: 'Mot de passe', controller: _passCtrl, obscure: true, minLen: 6),
                      if (app.flowError != null) ...[
                        const SizedBox(height: 12),
                        Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
                      ],
                      const SizedBox(height: 24),
                      PrimaryButton(label: "S'inscrire", loading: app.busy, onPressed: () => _submit(app)),
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

  Widget _field({required String label, required TextEditingController controller, bool obscure = false, TextInputType? keyboardType, int minLen = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
        const SizedBox(height: 9),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Requis';
            if (v.trim().length < minLen) return 'Trop court';
            return null;
          },
          style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
          decoration: appFieldDecoration(),
        ),
      ],
    );
  }
}
