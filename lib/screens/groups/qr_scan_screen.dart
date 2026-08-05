import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

/// Full-screen camera scanner for joining a group via a QR invite code.
/// Pops with `true` once a join succeeds.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null) return;
    setState(() => _busy = true);
    final app = context.read<AppState>();
    final ok = await app.joinGroupByCode(raw);
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
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(AppRadius.xl)),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Text(
              "Cadrez le QR code d'invitation partagé par un membre du groupe.",
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
