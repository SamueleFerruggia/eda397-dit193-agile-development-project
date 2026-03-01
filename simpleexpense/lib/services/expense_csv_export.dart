import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

/// Builds a CSV string from a list of expenses and exports it via the share sheet.
/// Returns true if export was started, false if list was empty.
Future<bool> exportExpensesToCsv({
  required BuildContext context,
  required List<Expense> expenses,
  required String currency,
}) async {
  if (expenses.isEmpty) return false;

  final csv = _buildCsv(expenses, currency);
  final dir = await getTemporaryDirectory();
  final fileName =
      'expenses_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.csv';
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(csv, flush: true);

  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path)],
    subject: 'Expenses export',
    text: 'Expenses export (${expenses.length} items)',
  ));
  return true;
}

String _escapeCsv(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String _buildCsv(List<Expense> expenses, String currency) {
  const header =
      'Date,Time,Description,Amount,Currency,Paid by,Split count,Category';
  final buffer = StringBuffer(header);
  buffer.writeln();

  for (final e in expenses) {
    final date =
        '${e.timestamp.year}-${e.timestamp.month.toString().padLeft(2, '0')}-${e.timestamp.day.toString().padLeft(2, '0')}';
    final time =
        '${e.timestamp.hour.toString().padLeft(2, '0')}:${e.timestamp.minute.toString().padLeft(2, '0')}';
    buffer.writeln([
      date,
      time,
      _escapeCsv(e.description),
      e.amount.toStringAsFixed(2),
      currency,
      _escapeCsv(e.payerName),
      e.splitAmounts.length.toString(),
      _escapeCsv(e.category),
    ].join(','));
  }
  return buffer.toString();
}
