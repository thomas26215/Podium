import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/saved_account.dart';
import '../../state/app_state.dart';
import '../../state/session_manager.dart';
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

  /// uids currently being silently re-checked (see [_tapSavedAccount]) —
  /// just enough state to show a spinner on that one chip while it happens.
  final Set<String> _restoringUids = {};

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

  /// Instant switch if it's already open; otherwise, before giving up to
  /// the plain "type your password" fallback, gives its own persisted
  /// Firebase session one chance to restore silently — covers the saved
  /// accounts the app hasn't gotten around to (or couldn't) reconnect yet
  /// in the background (see SessionManager._restoreOtherSavedAccounts).
  Future<void> _tapSavedAccount(SessionManager? manager, SavedAccount account) async {
    if (manager == null || account.uid.isEmpty) {
      _prefillEmail(account);
      return;
    }
    if (manager.hasOpenSession(account.uid)) {
      manager.switchTo(account.uid);
      return;
    }
    setState(() => _restoringUids.add(account.uid));
    final restored = await manager.tryRestore(account.email, account.uid);
    if (!mounted) return;
    setState(() => _restoringUids.remove(account.uid));
    if (restored) {
      manager.switchTo(account.uid);
    } else {
      _prefillEmail(account);
    }
  }

  void _prefillEmail(SavedAccount account) {
    _emailCtrl.text = account.email;
    _emailCtrl.selection = TextSelection.collapsed(offset: account.email.length);
  }

  /// Null when no [SessionManager] is provided above this screen (e.g. the
  /// widget tests, which wrap a bare `AppState` without going through
  /// `main.dart`'s provider tree) — saved-account chips then simply fall
  /// back to "prefill the e-mail" for every account, same as before this
  /// feature existed, rather than crashing.
  SessionManager? _watchSessionManager(BuildContext context) {
    try {
      return context.watch<SessionManager>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sessionManager = _watchSessionManager(context);
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
                    FadeSlideIn(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _field(label: 'E-mail', controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 16),
                          _field(label: 'Mot de passe', controller: _passCtrl, obscure: true),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => ChangeNotifierProvider.value(value: app, child: _ForgotPasswordDialog(initialEmail: _emailCtrl.text)),
                                ),
                                child: Text('Mot de passe oublié ?', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                              ),
                            ),
                          ),
                          if (app.flowError != null) ...[
                            const SizedBox(height: 12),
                            Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
                          ],
                          const SizedBox(height: 24),
                          PrimaryButton(label: 'Se connecter', loading: app.busy, onPressed: () => _submit(app)),
                        ],
                      ),
                    ),
                    if (savedAccounts.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Comptes enregistrés', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final account in savedAccounts)
                                  Pressable(
                                    onTap: _restoringUids.contains(account.uid) ? null : () => _tapSavedAccount(sessionManager, account),
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
                                          Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              if (_restoringUids.contains(account.uid))
                                                const SizedBox(width: 28, height: 28, child: Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2)))
                                              else
                                                Avatar(initial: account.displayName.isNotEmpty ? account.displayName[0].toUpperCase() : '?', color: Color(account.color), size: 28, fontSize: 11),
                                              if (account.uid.isNotEmpty && (sessionManager?.hasOpenSession(account.uid) ?? false))
                                                Positioned(
                                                  right: -2,
                                                  bottom: -2,
                                                  child: Container(
                                                    width: 11,
                                                    height: 11,
                                                    decoration: BoxDecoration(
                                                      color: AppColors.accent,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: AppColors.card, width: 2),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
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
                                            onTap: () {
                                              app.removeSavedAccount(account.email);
                                              if (account.uid.isNotEmpty && (sessionManager?.hasOpenSession(account.uid) ?? false)) {
                                                sessionManager!.closeSession(account.uid);
                                              }
                                            },
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
                            Text(
                              savedAccounts.any((a) => a.uid.isNotEmpty && (sessionManager?.hasOpenSession(a.uid) ?? false))
                                  ? 'Le point orange = déjà connecté, touchez pour y basculer instantanément. Sinon, ça remplit l’e-mail — ✕ pour l’oublier.'
                                  : 'Touchez un compte pour remplir l’e-mail, ou ✕ pour l’oublier sur cet appareil.',
                              style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                            ),
                          ],
                        ),
                      ),
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

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;
  const _ForgotPasswordDialog({required this.initialEmail});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final _emailCtrl = TextEditingController(text: widget.initialEmail);
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    if (_emailCtrl.text.trim().isEmpty) return;
    final ok = await app.sendPasswordResetEmail(_emailCtrl.text);
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Dialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mot de passe oublié', style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            if (_sent) ...[
              Text(
                "Si un compte existe avec cette adresse, un e-mail de réinitialisation vient d'être envoyé. Pensez à vérifier vos spams s'il n'arrive pas d'ici quelques minutes.",
                style: bodyFont(size: 13.5, weight: FontWeight.w600, color: AppColors.mut),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  ),
                  child: Text('Fermer', style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                ),
              ),
            ] else ...[
              Text(
                'Entrez votre adresse e-mail : nous vous enverrons un lien pour choisir un nouveau mot de passe.',
                style: bodyFont(size: 13.5, weight: FontWeight.w600, color: AppColors.mut),
              ),
              const SizedBox(height: 18),
              Text('E-mail', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
              const SizedBox(height: 9),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
                decoration: appFieldDecoration(),
              ),
              if (app.flowError != null) ...[
                const SizedBox(height: 8),
                Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: Colors.red)),
              ],
              const SizedBox(height: 20),
              PrimaryButton(label: 'Envoyer le lien', loading: app.busy, onPressed: () => _submit(app)),
            ],
          ],
        ),
      ),
    );
  }
}
