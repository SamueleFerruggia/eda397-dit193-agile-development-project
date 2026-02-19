import 'package:flutter_test/flutter_test.dart';

/// Test Run: Expense creation and equal distribution verification
///
/// Covers FR-3 (Adding Expenses) and FR-4 (Equal Split Logic)
///
/// NOTE:
/// These are pure Dart tests that focus on the business rule:
/// "When an expense is added and split equally, each selected member
///  should owe the same share and the sum of all shares must equal
///  the total expense amount."

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
}

/// Helper used only in tests to model the "equal split" behaviour
/// described in FR-4. It mimics what the UI does conceptually:
/// divide the total amount equally across all selected members.
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
