import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

/// Builds a PDF from a list of expenses and exports it via the share sheet.
/// Returns true if export was started, false if list was empty.
Future<bool> exportExpensesToPdf({
  required List<Expense> expenses,
  required String currency,
  String groupName = 'Expenses',
}) async {
  if (expenses.isEmpty) return false;

  final pdf = pw.Document();
  final dateStr = (DateTime e) =>
      '${e.year}-${e.month.toString().padLeft(2, '0')}-${e.day.toString().padLeft(2, '0')}';
  final timeStr = (DateTime e) =>
      '${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}';

  final headers = ['Date', 'Time', 'Description', 'Amount', 'Paid by', 'Split'];
  final data = <List<String>>[
    headers,
    ...expenses.map(
      (e) => [
        dateStr(e.timestamp),
        timeStr(e.timestamp),
        e.description,
        '${e.amount.toStringAsFixed(2)} $currency',
        e.payerName,
        '${e.splitAmounts.length}',
      ],
    ),
  ];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          groupName,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
      ),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          data: data,
          headerCount: 1,
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerStyle: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
        ),
      ],
    ),
  );

  final bytes = await pdf.save();
  final dir = await getTemporaryDirectory();
  final fileName =
      'expenses_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.pdf';
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      subject: 'Expenses export',
      text: 'Expenses export (${expenses.length} items)',
    ),
  );
  return true;
}
