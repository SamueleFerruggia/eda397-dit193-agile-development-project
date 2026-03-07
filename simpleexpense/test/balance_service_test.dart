import 'package:flutter_test/flutter_test.dart';
import 'package:simpleexpense/models/models.dart';
import 'package:simpleexpense/services/balance_service.dart';

/// Uses in-memory Expense/GroupMember data only.
void main() {
  late BalanceService balanceService;

  setUp(() {
    balanceService = BalanceService();
  });

  group('Net balances', () {
    test('Single expense split equally: payer credited, others debited', () {
      final members = [
        GroupMember(uid: 'u1', name: 'Alice', email: 'a@x.com'),
        GroupMember(uid: 'u2', name: 'Bob', email: 'b@x.com'),
      ];
      final expenses = [
        Expense(
          id: 'e1',
          groupId: 'g1',
          description: 'Lunch',
          amount: 100,
          payerId: 'u1',
          payerName: 'Alice',
          splitWith: ['u1', 'u2'],
          splitAmounts: {'u1': 50, 'u2': 50},
          timestamp: DateTime.now(),
        ),
      ];

      final balances = balanceService.calculateNetBalances(expenses, members);

      expect(balances['u1'], 50); // paid 100, owes 50 → +50
      expect(balances['u2'], -50); // paid 0, owes 50 → -50
    });

    test('Two expenses: balances sum correctly', () {
      final members = [
        GroupMember(uid: 'u1', name: 'A', email: 'a@x.com'),
        GroupMember(uid: 'u2', name: 'B', email: 'b@x.com'),
      ];
      final expenses = [
        Expense(
          id: 'e1',
          groupId: 'g1',
          description: 'Dinner',
          amount: 60,
          payerId: 'u1',
          payerName: 'A',
          splitWith: ['u1', 'u2'],
          splitAmounts: {'u1': 30, 'u2': 30},
          timestamp: DateTime.now(),
        ),
        Expense(
          id: 'e2',
          groupId: 'g1',
          description: 'Taxi',
          amount: 40,
          payerId: 'u2',
          payerName: 'B',
          splitWith: ['u1', 'u2'],
          splitAmounts: {'u1': 20, 'u2': 20},
          timestamp: DateTime.now(),
        ),
      ];

      final balances = balanceService.calculateNetBalances(expenses, members);

      // u1: paid 60, owes 30+20=50 → +10. u2: paid 40, owes 30+20=50 → -10
      expect(balances['u1'], 10);
      expect(balances['u2'], -10);
    });
  });

  group('Settlements', () {
    test('One debtor, one creditor: single settlement', () {
      final balances = {'u1': 50.0, 'u2': -50.0};
      final settlements = balanceService.calculateSettlements(balances);

      expect(settlements.length, 1);
      expect(settlements.first.fromUserId, 'u2');
      expect(settlements.first.toUserId, 'u1');
      expect(settlements.first.amount, 50);
    });

    test('Small balance below threshold is ignored', () {
      final balances = {'u1': 0.005, 'u2': -0.005};
      final settlements = balanceService.calculateSettlements(balances);

      expect(settlements.isEmpty, true);
    });

    test('Multiple creditors and debtors produce expected settlements', () {
      // u1 is owed 50, u2 is owed 30, u3 owes 40, u4 owes 40
      final balances = {'u1': 50.0, 'u2': 30.0, 'u3': -40.0, 'u4': -40.0};

      final settlements = balanceService.calculateSettlements(balances);

      expect(settlements.length, 3);

      // Convert to a map for easier assertions: from->to -> amount
      final byKey = {
        for (final s in settlements) '${s.fromUserId}->${s.toUserId}': s.amount,
      };

      expect(byKey['u3->u1'], 40.0);
      expect(byKey['u4->u1'], 10.0);
      expect(byKey['u4->u2'], 30.0);
    });

    test('getUserSettlements returns only settlements involving that user', () {
      final balances = {'u1': 50.0, 'u2': 30.0, 'u3': -40.0, 'u4': -40.0};

      final u4Settlements = balanceService.getUserSettlements('u4', balances);

      // u4 participates in two settlements in the scenario above
      expect(u4Settlements.length, 2);
      expect(
        u4Settlements.any(
          (s) => s.fromUserId == 'u4' && s.toUserId == 'u1' && s.amount == 10.0,
        ),
        isTrue,
      );
      expect(
        u4Settlements.any(
          (s) => s.fromUserId == 'u4' && s.toUserId == 'u2' && s.amount == 30.0,
        ),
        isTrue,
      );
    });
  });
}
