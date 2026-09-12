import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../models/group_invite_code.dart';
import '../../models/server_invite_code.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

/// What kind of invite code [QrScanScreen] expects — determines which
/// `AppState.join*ByCode` method a scanned code is handed to. [auto] (the
/// default from the unified "Rejoindre" entry point on [GroupsScreen])
/// figures it out from the code's own shape instead of requiring the user
/// to pick a kind before they've even scanned anything.
enum QrJoinTarget { auto, group, server, salon }

/// Full-screen camera scanner for joining a group/server/salon via a QR
/// invite code. Pops with `true` once a join succeeds.
class QrScanScreen extends StatefulWidget {
  final QrJoinTarget target;
  const QrScanScreen({super.key, this.target = QrJoinTarget.auto});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> with SingleTickerProviderStateMixin {
  final _controller = MobileScannerController();
  bool _busy = false;

  // Purely decorative sweep inside the scan frame — like LiveDot's pulse,
  // this repeats forever, so it's confined to a screen no test ever pumps
  // (a real camera scanner isn't something widget tests exercise).
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    _sweep.dispose();
    super.dispose();
  }

  /// [widget.target] itself unless it's [QrJoinTarget.auto], in which case
  /// this sniffs `raw`'s own shape (see GroupInviteCode/ServerInviteCode/
  /// SalonInviteCode — each uses a distinct URI host) to figure out which
  /// kind of invite it is without asking the user to guess first.
  QrJoinTarget _resolveTarget(String raw) {
    if (widget.target != QrJoinTarget.auto) return widget.target;
    if (GroupInviteCode.tryParse(raw) != null) return QrJoinTarget.group;
    if (SalonInviteCode.tryParse(raw) != null) return QrJoinTarget.salon;
    if (ServerInviteCode.tryParse(raw) != null) return QrJoinTarget.server;
    return QrJoinTarget.auto;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null) return;
    setState(() => _busy = true);
    final app = context.read<AppState>();
    final resolved = _resolveTarget(raw);
    if (resolved == QrJoinTarget.auto) {
      // Doesn't match any known invite shape — nothing was actually
      // attempted, so app.flowError could only be stale from a previous try.
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code QR invalide.')));
      return;
    }
    final ok = switch (resolved) {
      QrJoinTarget.auto => false, // unreachable, handled above
      QrJoinTarget.group => await app.joinGroupByCode(raw),
      QrJoinTarget.server => await app.joinServerByCode(raw),
      QrJoinTarget.salon => await app.joinSalonByCode(raw),
    };
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.flowError ?? 'Code QR invalide.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Scanner un QR code', style: bodyFont(size: 17, weight: FontWeight.w800, color: Colors.white)),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: AnimatedBuilder(
                animation: _sweep,
                builder: (context, _) {
                  // Ping-pongs 0->1->0 across the frame instead of snapping
                  // back to the top, so the sweep reads as a continuous scan.
                  final t = _sweep.value < 0.5 ? _sweep.value * 2 : (1 - _sweep.value) * 2;
                  return Align(
                    alignment: Alignment(0, -1 + 2 * t),
                    child: Container(
                      width: double.infinity,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.transparent, AppColors.accent, Colors.transparent]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Text(
              switch (widget.target) {
                QrJoinTarget.auto => "Cadrez un QR code d'invitation — groupe, serveur ou salon.",
                QrJoinTarget.group => "Cadrez le QR code d'invitation partagé par un membre du groupe.",
                QrJoinTarget.server => "Cadrez le QR code d'invitation partagé par un membre du serveur.",
                QrJoinTarget.salon => "Cadrez le QR code d'invitation partagé pour ce salon.",
              },
              textAlign: TextAlign.center,
              style: bodyFont(size: 14, weight: FontWeight.w600, color: Colors.white),
            ),
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
