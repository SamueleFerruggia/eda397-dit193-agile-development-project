import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/auth_provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/services/balance_service.dart';
import 'package:simpleexpense/services/firestore_service.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'package:simpleexpense/models/models.dart';

/// Custom header widget for expense screens
class ExpenseHeaderWidget extends StatelessWidget {
  const ExpenseHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Consumer<GroupsProvider>(
        builder: (context, groupsProvider, child) {
          final inviteCode = groupsProvider.currentInviteCode ?? '------';
          return Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.textLight),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (inviteCode != '------') {
                    Share.share(
                      'Join my group in Simple Expense!\n\nInvite Code: $inviteCode',
                      subject: 'Join my Simple Expense group',
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Share Invite Code',
                      style: TextStyle(
                        color: AppTheme.secondaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          inviteCode,
                          style: const TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.share,
                          color: AppTheme.textLight,
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Custom group info widget for displaying group name and user's net balance
class GroupInfoWidget extends StatelessWidget {
  const GroupInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final balanceService = BalanceService();
    final firestoreService = FirestoreService();

    return Consumer2<GroupsProvider, AuthProvider>(
      builder: (context, groupsProvider, authProvider, child) {
        final groupId = groupsProvider.currentGroupId;
        final currentUserId = authProvider.currentUserId;
        final currency = groupsProvider.currentCurrency ?? 'SEK';

        if (groupId == null || currentUserId == null) {
          return _buildGroupInfoContainer(
            context,
            groupsProvider.currentGroupName ?? 'Group Name',
            '—',
            AppTheme.textDark,
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('groups')
              .doc(groupId)
              .collection('expenses')
              .snapshots(),
          builder: (context, expenseSnapshot) {
            if (!expenseSnapshot.hasData) {
              return _buildGroupInfoContainer(
                context,
                groupsProvider.currentGroupName ?? 'Group Name',
                '—',
                AppTheme.textDark,
              );
            }

            final expenses = expenseSnapshot.data!.docs
                .map((doc) => Expense.fromFirestore(doc))
                .toList();

            return FutureBuilder<List<GroupMember>>(
              future: firestoreService.getGroupMembers(groupId),
              builder: (context, memberSnapshot) {
                if (!memberSnapshot.hasData) {
                  return _buildGroupInfoContainer(
                    context,
                    groupsProvider.currentGroupName ?? 'Group Name',
                    '—',
                    AppTheme.textDark,
                  );
                }

                final members = memberSnapshot.data!;
                final balances =
                    balanceService.calculateNetBalances(expenses, members);
                final myBalance = balances[currentUserId] ?? 0.0;

                final isPositive = myBalance > 0.01;
                final isNegative = myBalance < -0.01;

                String statusText;
                Color statusColor;

                if (isPositive) {
                  statusText =
                      'You are owed ${myBalance.toStringAsFixed(2)} $currency';
                  statusColor = AppTheme.secondaryDark;
                } else if (isNegative) {
                  statusText =
                      'You owe ${(-myBalance).toStringAsFixed(2)} $currency';
                  statusColor = AppTheme.primaryDark;
                } else {
                  statusText = 'Settled up';
                  statusColor = AppTheme.textDark;
                }

                return _buildGroupInfoContainer(
                  context,
                  groupsProvider.currentGroupName ?? 'Group Name',
                  statusText,
                  statusColor,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGroupInfoContainer(
    BuildContext context,
    String groupName,
    String statusText,
    Color statusColor,
  ) {
    return Container(
      color: Colors.grey[300],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppTheme.background),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget showing user's balance status for a group (You owe / You are owed)
class GroupBalanceStatusWidget extends StatelessWidget {
  final String groupId;
  final String currency;

  const GroupBalanceStatusWidget({
    super.key,
    required this.groupId,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final balanceService = BalanceService();
    final firestoreService = FirestoreService();

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final currentUserId = authProvider.currentUserId;

        if (currentUserId == null) {
          return Text(
            '—',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppTheme.textDark,
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('groups')
              .doc(groupId)
              .collection('expenses')
              .snapshots(),
          builder: (context, expenseSnapshot) {
            if (!expenseSnapshot.hasData) {
              return Text(
                '—',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textDark,
                ),
              );
            }

            final expenses = expenseSnapshot.data!.docs
                .map((doc) => Expense.fromFirestore(doc))
                .toList();

            return FutureBuilder<List<GroupMember>>(
              future: firestoreService.getGroupMembers(groupId),
              builder: (context, memberSnapshot) {
                if (!memberSnapshot.hasData) {
                  return Text(
                    '—',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textDark,
                    ),
                  );
                }

                final members = memberSnapshot.data!;
                final balances =
                    balanceService.calculateNetBalances(expenses, members);
                final myBalance = balances[currentUserId] ?? 0.0;

                final isPositive = myBalance > 0.01;
                final isNegative = myBalance < -0.01;

                String statusText;
                Color statusColor;

                if (isPositive) {
                  statusText =
                      'You are owed ${myBalance.toStringAsFixed(2)} $currency';
                  statusColor = AppTheme.secondaryDark;
                } else if (isNegative) {
                  statusText =
                      'You owe ${(-myBalance).toStringAsFixed(2)} $currency';
                  statusColor = AppTheme.primaryDark;
                } else {
                  statusText = 'Settled up';
                  statusColor = AppTheme.textDark;
                }

                return Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
