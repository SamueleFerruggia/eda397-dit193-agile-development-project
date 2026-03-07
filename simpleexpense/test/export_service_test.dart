import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simpleexpense/models/models.dart';
import 'package:simpleexpense/services/expense_csv_export.dart';
import 'package:simpleexpense/services/expense_pdf_export.dart';

void main() {
  group('Export to CSV', () {
    testWidgets('returns false and does not crash when there are no expenses', (
      WidgetTester tester,
    ) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final result = await exportExpensesToCsv(
        context: capturedContext,
        expenses: <Expense>[],
        currency: 'SEK',
      );

      expect(result, isFalse);
    });
  });

  group('Export to PDF', () {
    test('returns false when there are no expenses', () async {
      final result = await exportExpensesToPdf(
        expenses: <Expense>[],
        currency: 'SEK',
      );

      expect(result, isFalse);
    });
  });
}
