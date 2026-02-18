import 'dart:math';
import '../models/models.dart';

/// Service for calculating net balances and settlements in a group
class BalanceService {
  /// Calculate net balances for all members in a group
  /// Returns a map of userId -> net balance
  /// Positive balance = person is owed money
  /// Negative balance = person owes money
  Map<String, double> calculateNetBalances(
    List<Expense> expenses,
    List<GroupMember> members,
  ) {
    // Initialize all member balances to 0
    Map<String, double> balances = {};
    for (var member in members) {
      balances[member.uid] = 0.0;
    }

    // Process each expense
    for (var expense in expenses) {
      // The payer gets credited the full amount (positive balance)
      balances[expense.payerId] = 
        (balances[expense.payerId] ?? 0) + expense.amount;

      // Calculate how much each participant owes
      double splitAmount = expense.amount / expense.splitWith.length;

      // Deduct the split amount from each participant
      for (var participantId in expense.splitWith) {
        balances[participantId] = 
          (balances[participantId] ?? 0) - splitAmount;
      }
    }

    return balances;
  }

  /// Calculate simplified settlements (who should pay whom)
  /// This minimizes the number of transactions needed
  List<Settlement> calculateSettlements(Map<String, double> balances) {
    List<Settlement> settlements = [];

    // Separate creditors (people who are owed) and debtors (people who owe)
    List<MapEntry<String, double>> creditors = [];
    List<MapEntry<String, double>> debtors = [];

    balances.forEach((uid, balance) {
      if (balance > 0.01) {
        // Person is owed money
        creditors.add(MapEntry(uid, balance));
      } else if (balance < -0.01) {
        // Person owes money (convert to positive for easier calculation)
        debtors.add(MapEntry(uid, -balance));
      }
    });

    // Sort by amount (largest first) for optimal matching
    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    // Match debtors with creditors to minimize transactions
    int i = 0; // debtor index
    int j = 0; // creditor index

    while (i < debtors.length && j < creditors.length) {
      // Take the minimum of what debtor owes and creditor is owed
      double amount = min(debtors[i].value, creditors[j].value);

      // Create a settlement transaction
      settlements.add(Settlement(
        fromUserId: debtors[i].key,
        toUserId: creditors[j].key,
        amount: amount,
      ));

      // Update remaining amounts
      debtors[i] = MapEntry(debtors[i].key, debtors[i].value - amount);
      creditors[j] = MapEntry(creditors[j].key, creditors[j].value - amount);

      // Move to next debtor/creditor if current one is settled
      if (debtors[i].value < 0.01) i++;
      if (creditors[j].value < 0.01) j++;
    }

    return settlements;
  }

  /// Get balance for a specific user in the group
  double getUserBalance(
    String userId,
    List<Expense> expenses,
    List<GroupMember> members,
  ) {
    final balances = calculateNetBalances(expenses, members);
    return balances[userId] ?? 0.0;
  }

  /// Get total amount a user has paid
  double getTotalPaid(String userId, List<Expense> expenses) {
    return expenses
        .where((expense) => expense.payerId == userId)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Get total amount a user owes (their share of all expenses)
  double getTotalOwed(String userId, List<Expense> expenses) {
    double total = 0.0;
    for (var expense in expenses) {
      if (expense.splitWith.contains(userId)) {
        total += expense.amount / expense.splitWith.length;
      }
    }
    return total;
  }

  /// Get settlements involving a specific user
  List<Settlement> getUserSettlements(
    String userId,
    Map<String, double> balances,
  ) {
    final allSettlements = calculateSettlements(balances);
    return allSettlements.where((settlement) =>
      settlement.fromUserId == userId || settlement.toUserId == userId
    ).toList();
  }
}

/// Represents a settlement transaction between two users
class Settlement {
  final String fromUserId;
  final String toUserId;
  final double amount;

  Settlement({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  @override
  String toString() {
    return 'Settlement(from: $fromUserId, to: $toUserId, amount: $amount)';
  }
}