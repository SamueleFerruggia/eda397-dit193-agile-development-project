import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group creation flow', () {
    test('Creator becomes admin and initial member', () {
      const groupName = 'Trip to Spain';
      const creatorId = 'user_123';
      const currency = 'SEK';
      const inviteCode = 'ABC123';
      const invitedEmails = ['friend1@example.com', 'friend2@example.com'];

      final groupData = buildGroupData(
        groupName: groupName,
        creatorId: creatorId,
        invitedEmails: invitedEmails,
        currency: currency,
        inviteCode: inviteCode,
      );

      expect(groupData['groupName'], groupName);
      expect(groupData['adminId'], creatorId);
      expect(groupData['members'], [creatorId]);
      expect(groupData['currency'], currency);
      expect(groupData['inviteCode'], inviteCode);
      expect(groupData['invitedEmails'], invitedEmails);
    });

    test('Group stores all invited member emails', () {
      const creatorId = 'user_123';
      const invitedEmails = ['a@example.com', 'b@example.com', 'c@example.com'];

      final groupData = buildGroupData(
        groupName: 'Project X',
        creatorId: creatorId,
        invitedEmails: invitedEmails,
        currency: 'EUR',
        inviteCode: 'XYZ789',
      );

      expect(groupData['invitedEmails'], invitedEmails);
      expect((groupData['invitedEmails'] as List).length, invitedEmails.length);
    });
  });

  group('Admin verification', () {
    test('Exactly one admin is assigned and others are members', () {
      const adminId = 'admin_1';
      const memberIds = ['admin_1', 'u2', 'u3', 'u4'];

      final roles = computeMemberRoles(adminId, memberIds);

      // Check that all expected users are present.
      expect(roles.keys.toSet(), memberIds.toSet());

      // Admin has role "admin".
      expect(roles[adminId], 'admin');

      // All other members have role "member".
      for (final uid in memberIds.where((id) => id != adminId)) {
        expect(roles[uid], 'member');
      }
    });

    test('If admin is not in member list, everyone is just member', () {
      const adminId = 'admin_not_in_list';
      const memberIds = ['u1', 'u2', 'u3'];

      final roles = computeMemberRoles(adminId, memberIds);

      for (final uid in memberIds) {
        expect(roles[uid], 'member');
      }
    });
  });

  group('Expense entry flow and equal distribution', () {
    test(
      'Expense entry stores payer and equal split for all selected members',
      () {
        const groupId = 'group_1';
        const description = 'Dinner';
        const amount = 120.0;
        const payerId = 'user_payer';
        const participants = ['user_payer', 'u2', 'u3', 'u4'];

        final expense = createExpenseData(
          groupId: groupId,
          description: description,
          amount: amount,
          payerId: payerId,
          participantIds: participants,
        );

        expect(expense['groupId'], groupId);
        expect(expense['description'], description);
        expect(expense['amount'], amount);
        expect(expense['payerId'], payerId);
        expect(expense['splitWith'], participants);

        final splitAmounts =
            (expense['splitAmounts'] as Map<String, double>?) ?? {};

        // All selected participants must have a share.
        expect(splitAmounts.keys.toSet(), participants.toSet());

        // All shares are equal.
        expect(splitAmounts.values.toSet().length, 1);
        expect(splitAmounts['user_payer'], 30.0);
        expect(splitAmounts['u2'], 30.0);
        expect(splitAmounts['u3'], 30.0);
        expect(splitAmounts['u4'], 30.0);

        // Sum of shares equals total amount.
        final totalShares = splitAmounts.values.fold<double>(
          0.0,
          (sum, v) => sum + v,
        );
        expect(totalShares, amount);
      },
    );

    test(
      'Changing participants changes each individual share but still sums up',
      () {
        const groupId = 'group_2';
        const description = 'Hotel';
        const amount = 150.0;
        const payerId = 'user_payer';
        const participants = ['user_payer', 'u2', 'u3'];

        final expense = createExpenseData(
          groupId: groupId,
          description: description,
          amount: amount,
          payerId: payerId,
          participantIds: participants,
        );

        final splitAmounts =
            (expense['splitAmounts'] as Map<String, double>?) ?? {};

        expect(splitAmounts.keys.toSet(), participants.toSet());

        // 150 / 3 = 50 per person.
        expect(splitAmounts['user_payer'], 50.0);
        expect(splitAmounts['u2'], 50.0);
        expect(splitAmounts['u3'], 50.0);

        final totalShares = splitAmounts.values.fold<double>(
          0.0,
          (sum, v) => sum + v,
        );
        expect(totalShares, amount);
      },
    );

    test('Zero amount results in zero shares for all participants', () {
      const groupId = 'group_3';
      const description = 'Free event';
      const amount = 0.0;
      const payerId = 'user_payer';
      const participants = ['user_payer', 'u2', 'u3'];

      final expense = createExpenseData(
        groupId: groupId,
        description: description,
        amount: amount,
        payerId: payerId,
        participantIds: participants,
      );

      final splitAmounts =
          (expense['splitAmounts'] as Map<String, double>?) ?? {};

      for (final uid in participants) {
        expect(splitAmounts[uid], 0.0);
      }

      final totalShares = splitAmounts.values.fold<double>(
        0.0,
        (sum, v) => sum + v,
      );
      expect(totalShares, 0.0);
    });
  });
}

/// Helper that models what a group document should contain when created.
Map<String, dynamic> buildGroupData({
  required String groupName,
  required String creatorId,
  required List<String> invitedEmails,
  required String currency,
  required String inviteCode,
}) {
  return {
    'groupName': groupName,
    'adminId': creatorId,
    'inviteCode': inviteCode,
    'currency': currency,
    'members': [creatorId],
    'invitedEmails': invitedEmails,
  };
}

/// Helper that decides which user is admin and which ones are members.
Map<String, String> computeMemberRoles(String adminId, List<String> memberIds) {
  final roles = <String, String>{};

  for (final id in memberIds) {
    // Only mark as admin if the id matches the adminId.
    roles[id] = (id == adminId) ? 'admin' : 'member';
  }

  return roles;
}

/// Helper that models the data structure for an expense creation,
/// including equal split across all selected participants.
Map<String, dynamic> createExpenseData({
  required String groupId,
  required String description,
  required double amount,
  required String payerId,
  required List<String> participantIds,
}) {
  final splitAmounts = _calculateEqualSplit(amount, participantIds);

  return {
    'groupId': groupId,
    'description': description,
    'amount': amount,
    'payerId': payerId,
    'splitWith': participantIds,
    'splitAmounts': splitAmounts,
  };
}

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
