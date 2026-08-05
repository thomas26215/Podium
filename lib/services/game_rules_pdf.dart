import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/game.dart';

/// Renders a game's rules reminders (see [Game.ruleSections]) as a PDF and
/// opens the OS print/share sheet so the group can save or send it —
/// e.g. to print a physical copy for game night.
Future<void> exportGameRulesPdf(Game game) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('${game.emoji}  ${game.name}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(game.category, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.SizedBox(height: 20),
        if (game.ruleSections.isEmpty)
          pw.Text('Aucune règle enregistrée.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700))
        else
          for (final section in game.ruleSections) ...[
            pw.Text(section.title, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            for (final rule in section.rules) pw.Bullet(text: rule, style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 16),
          ],
      ],
    ),
  );
  await Printing.layoutPdf(onLayout: (_) => doc.save(), name: '${game.name} — règles');
}
