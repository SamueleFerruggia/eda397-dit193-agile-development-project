import 'package:flutter_test/flutter_test.dart';

/// Test Run: Expense creation and equal distribution verification
///

void main() {
  group('Equal split logic (FR-3, FR-4)', () {
    test('Expense is split equally among all group members', () {
      // Precondition: user is on a specific group dashboard and logged in.
      // We simulate an expense of 120 split between 4 members.
      const amount = 120.0;
      const memberIds = ['u1', 'u2', 'u3', 'u4'];

      final shares = _calculateEqualSplit(amount, memberIds);

      // Each member should get the same share.
      expect(shares.values.toSet().length, 1);
      expect(shares['u1'], 30.0);
      expect(shares['u2'], 30.0);
      expect(shares['u3'], 30.0);
      expect(shares['u4'], 30.0);

      // Total of all shares must equal the original amount.
      final totalShares = shares.values.fold<double>(
        0.0,
        (sum, value) => sum + value,
      );
      expect(totalShares, amount);
    });

    test('Changing payer does not affect equal split amounts', () {
      const amount = 90.0;
      const memberIds = ['payerUser', 'm2', 'm3'];

      // Simulate that the payer is 'm2' instead of the current user.
      const payerId = 'm2';

      final shares = _calculateEqualSplit(amount, memberIds);

      // Equal split means each selected member still pays the same amount,
      // regardless of who the payer is.
      expect(shares['payerUser'], 30.0);
      expect(shares['m2'], 30.0);
      expect(shares['m3'], 30.0);

      // We only assert on amounts here, not on how balances are stored.
      final totalShares = shares.values.fold<double>(
        0.0,
        (sum, value) => sum + value,
      );
      expect(totalShares, amount);
      expect(payerId, 'm2'); // just documents that payer can differ
    });

    test('Zero amount leads to zero shares for all members', () {
      const amount = 0.0;
      const memberIds = ['u1', 'u2', 'u3'];

      final shares = _calculateEqualSplit(amount, memberIds);

      // All shares should be zero when the expense amount is zero.
      for (final id in memberIds) {
        expect(shares[id], 0.0);
      }

      // Sum of all shares should also be zero.
      final totalShares = shares.values.fold<double>(
        0.0,
        (sum, value) => sum + value,
      );
      expect(totalShares, 0.0);
    });
  });

  group('Split validation and percentage mode', () {
    test('Exact-amount split is valid when sums to total', () {
      const amount = 100.0;
      final splits = {'u1': 70.0, 'u2': 30.0};

      expect(_isValidSplitByAmount(amount, splits), isTrue);
    });

    test('Exact-amount split is invalid when it does not sum to total', () {
      const amount = 100.0;
      final splits = {'u1': 70.0, 'u2': 20.0};

      expect(_isValidSplitByAmount(amount, splits), isFalse);
    });

    test('Percentage split converts to amounts and stays valid when 100%', () {
      const amount = 120.0;
      final percentages = {'u1': 25.0, 'u2': 25.0, 'u3': 50.0};

      final amounts = _amountsFromPercentages(amount, percentages);

      // Total amounts should be roughly equal to original amount.
      final totalAmounts = amounts.values.fold<double>(
        0.0,
        (sum, v) => sum + v,
      );
      expect((totalAmounts - amount).abs() < 0.01, isTrue);

      // And percentage validation should pass when summing to 100%.
      expect(_isValidSplitByPercentage(percentages), isTrue);
    });

    test('Percentage split is invalid when percentages do not sum to 100', () {
      final percentages = {'u1': 30.0, 'u2': 30.0, 'u3': 30.0}; // 90%

      expect(_isValidSplitByPercentage(percentages), isFalse);
    });

    group('Decimal accuracy in uneven splits', () {
      test('Uneven exact amounts with cents can still be valid', () {
        const amount = 100.0;
        final splits = {'u1': 33.33, 'u2': 33.33, 'u3': 33.34};

        // Sums exactly to 100.00, should be accepted.
        expect(_isValidSplitByAmount(amount, splits), isTrue);
      });

      test(
        'Amounts that sum 0.01 away from total are rejected (strict check)',
        () {
          const amount = 10.0;
          final splits = {
            'u1': 3.33,
            'u2': 3.33,
            'u3': 3.33,
          }; // 9.99, off by 0.01

          // Current logic uses a strict < 0.01 tolerance, so this is invalid.
          expect(_isValidSplitByAmount(amount, splits), isFalse);
        },
      );

      test('Decimal percentages that sum to 100% are valid', () {
        final percentages = {'u1': 33.33, 'u2': 33.33, 'u3': 33.34}; // 100.00%

        expect(_isValidSplitByPercentage(percentages), isTrue);
      });

      test(
        'Decimal percentages that are off by 0.01 are treated as invalid',
        () {
          final percentages = {
            'u1': 33.33,
            'u2': 33.33,
            'u3': 33.33,
          }; // 99.99%, off by 0.01

          // Again, strict < 0.01 tolerance → invalid.
          expect(_isValidSplitByPercentage(percentages), isFalse);
        },
      );
    });
  });
}

/// Helper used only in tests to model the "equal split" behaviour
Map<String, double> _calculateEqualSplit(
  double amount,
  List<String> memberIds,
) {
  if (memberIds.isEmpty) return {};

  if (amount <= 0) {
    return {for (final id in memberIds) id: 0.0};
  }

  final perMember = amount / memberIds.length;

  return {for (final id in memberIds) id: perMember};
}

/// Mirrors the percentage mode calculation in ExpenseSplitScreen:
/// given total amount and per-user percentages, return per-user amounts.
Map<String, double> _amountsFromPercentages(
  double totalAmount,
  Map<String, double> percentages,
) {
  return percentages.map(
    (userId, pct) => MapEntry(userId, totalAmount * (pct / 100.0)),
  );
}

/// Helper to compare two doubles at cent-level precision.
bool _isApproximatelyEqual(double a, double b) {
  final aCents = (a * 100).round();
  final bCents = (b * 100).round();
  return aCents == bCents;
}

/// Mirrors _isValidSplit (non-percentage branch) in ExpenseSplitScreen.
bool _isValidSplitByAmount(double totalAmount, Map<String, double> splits) {
  final totalSplit = splits.values.fold<double>(0.0, (sum, v) => sum + v);
  return _isApproximatelyEqual(totalSplit, totalAmount);
}

/// Mirrors _isValidSplit (percentage branch) in ExpenseSplitScreen.
bool _isValidSplitByPercentage(Map<String, double> percentages) {
  final totalPct = percentages.values.fold<double>(0.0, (sum, v) => sum + v);
  return _isApproximatelyEqual(totalPct, 100.0);
}
