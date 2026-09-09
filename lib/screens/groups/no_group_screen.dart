import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'group_form_dialog.dart';
import 'qr_scan_screen.dart';

/// Shown in place of [MainShell] right after sign-in when the user isn't a
/// member of any group yet — prompts them to create one or share their email
/// so an existing member can add them to theirs.
class NoGroupScreen extends StatelessWidget {
  const NoGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final email = app.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeading(eyebrow: 'Bienvenue', title: 'Rejoignez ou créez un groupe'),
              Text(
                "Vous ne faites partie d'aucun groupe pour l'instant. Créez le vôtre, ou demandez à un ami de vous ajouter au sien.",
                style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
              ),
              const SizedBox(height: 28),
              FadeSlideIn(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadius.xxl)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CRÉER UN GROUPE', style: bodyFont(size: 12, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.55), letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      Text('Lancez votre propre communauté et invitez vos amis.', style: bodyFont(size: 14, weight: FontWeight.w600, color: Colors.white)),
                      const SizedBox(height: 18),
                      PrimaryButton(
                        label: 'Créer un groupe',
                        onPressed: () => showDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: const GroupFormDialog())),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SectionHeader(title: 'Rejoindre un groupe existant'),
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Scannez le QR code d'invitation d'un ami pour rejoindre son groupe instantanément.",
                        style: bodyFont(size: 13.5, weight: FontWeight.w600, color: AppColors.ink2),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScanScreen())),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: BorderSide(color: AppColors.line, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                          minimumSize: const Size.fromHeight(0),
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                        label: Text('Scanner un QR code', style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        "Vous pouvez aussi demander à un ami de vous ajouter directement avec votre adresse e-mail, depuis l'écran Groupes de son application :",
                        style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Row(
                          children: [
                            Expanded(child: Text(email, style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink))),
                            IconButton(
                              icon: Icon(Icons.copy_rounded, size: 20, color: AppColors.mut),
                              onPressed: email.isEmpty
                                  ? null
                                  : () {
                                      Clipboard.setData(ClipboardData(text: email));
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adresse copiée')));
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
