import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../auth/invite_link_handler.dart';

/// Explains how to join a group, server or salon — scan the invite QR code
/// with the phone's camera, or open the invite link — and lets someone
/// paste an invite link they received elsewhere (e.g. on a computer).
/// Pops with `true` once a join succeeds.
class JoinByLinkDialog extends StatefulWidget {
  const JoinByLinkDialog({super.key});

  @override
  State<JoinByLinkDialog> createState() => _JoinByLinkDialogState();
}

class _JoinByLinkDialogState extends State<JoinByLinkDialog> {
  final _linkCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    final target = InviteTarget.parse(_linkCtrl.text);
    if (target == null) {
      setState(() => _error = "Ce n'est pas un lien d'invitation Podium.");
      return;
    }
    setState(() => _error = null);
    final ok = await target.join(app);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = app.flowError ?? "Cette invitation n'est plus valable.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Dialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rejoindre', style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 10),
            Text(
                "Scannez le QR code d'invitation avec l'appareil photo de votre téléphone, ou touchez le lien d'invitation reçu : Podium s'ouvrira pour vous faire rejoindre.",
                style: bodyFont(size: 13.5, weight: FontWeight.w600, color: AppColors.ink2)),
            const SizedBox(height: 18),
            Text("Vous avez reçu le lien ailleurs ? Collez-le ici :", style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
            const SizedBox(height: 8),
            TextField(
              controller: _linkCtrl,
              keyboardType: TextInputType.url,
              style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.ink),
              decoration: appFieldDecoration(hintText: 'https://thomas26215.github.io/Podium/rejoindre.html?c=…'),
              onSubmitted: (_) => _submit(app),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(label: 'Rejoindre', loading: app.busy, onPressed: () => _submit(app)),
          ],
        ),
      ),
    );
  }
}
