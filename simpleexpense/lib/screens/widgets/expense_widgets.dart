import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/auth_provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/services/balance_service.dart';
import 'package:simpleexpense/services/firestore_service.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'package:simpleexpense/models/models.dart';
import 'package:simpleexpense/screens/invitation_management_screen.dart';
import 'package:simpleexpense/services/expense_csv_export.dart';
import 'package:simpleexpense/services/expense_pdf_export.dart';
import 'share_invite_dialog.dart';

/// Custom header widget for expense screens.
/// [expensesForExport] when set (e.g. by GroupDashboard) enables the CSV Export button.
class ExpenseHeaderWidget extends StatelessWidget {
  final ValueNotifier<List<Expense>?>? expensesForExport;

  const ExpenseHeaderWidget({
    super.key,
    this.expensesForExport,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Consumer2<GroupsProvider, AuthProvider>(
        builder: (context, groupsProvider, authProvider, child) {
          final inviteCode = groupsProvider.currentInviteCode ?? '------';
          final groupName = groupsProvider.currentGroupName ?? 'Group';
          final selectedGroup = groupsProvider.selectedGroup;
          final currentUserId = authProvider.currentUserId;
          final isAdmin = selectedGroup?.adminId == currentUserId;

          return Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.textLight),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              // Export button (when expenses list is provided) – opens PDF/CSV choice
              if (expensesForExport != null)
                IconButton(
                  icon: const Icon(
                    Icons.download,
                    color: AppTheme.textLight,
                    size: 24,
                  ),
                  onPressed: () {
                    final list = expensesForExport!.value;
                    final currency =
                        groupsProvider.currentCurrency ?? 'SEK';
                    final groupName =
                        groupsProvider.currentGroupName ?? 'Group';
                    if (list == null || list.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('No expenses to export')),
                      );
                      return;
                    }
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        backgroundColor: AppTheme.background,
                        title: const Text('Export expenses'),
                        content: const Text(
                          'Choose export format',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancel'),
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              final ok = await exportExpensesToPdf(
                                expenses: list,
                                currency: currency,
                                groupName: groupName,
                              );
                              if (context.mounted && !ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('No expenses to export')),
                                );
                              }
                            },
                            icon: const Icon(Icons.picture_as_pdf, size: 20),
                            label: const Text('PDF'),
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              final ok = await exportExpensesToCsv(
                                context: context,
                                expenses: list,
                                currency: currency,
                              );
                              if (context.mounted && !ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('No expenses to export')),
                                );
                              }
                            },
                            icon: const Icon(Icons.table_chart, size: 20),
                            label: const Text('CSV'),
                          ),
                        ],
                      ),
                    );
                  },
                  tooltip: 'Export',
                ),
              // Manage Invitations button (admin only)
              if (isAdmin)
                IconButton(
                  icon: const Icon(
                    Icons.people_outline,
                    color: AppTheme.textLight,
                    size: 24,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const InvitationManagementScreen(),
                      ),
                    );
                  },
                  tooltip: 'Manage Invitations',
                ),
              const SizedBox(width: 8),
              // Share invite code
              GestureDetector(
                onTap: () {
                  if (inviteCode != '------') {
                    showDialog(
                      context: context,
                      builder: (context) => ShareInviteDialog(
                        groupName: groupName,
                        inviteCode: inviteCode,
                      ),
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
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          inviteCode,
                          style: const TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.share,
                          color: AppTheme.textLight,
                          size: 12,
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
            groupName: groupsProvider.currentGroupName ?? 'Group Name',
            statusText: '—',
            statusColor: AppTheme.textDark,
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
                groupName: groupsProvider.currentGroupName ?? 'Group Name',
                statusText: '—',
                statusColor: AppTheme.textDark,
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
                    groupName: groupsProvider.currentGroupName ?? 'Group Name',
                    statusText: '—',
                    statusColor: AppTheme.textDark,
                  );
                }

                final members = memberSnapshot.data!;
                final balances = balanceService.calculateNetBalances(
                  expenses,
                  members,
                );
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

                final totalAmount = expenses.fold(
                  0.0,
                  (sum, e) => sum + e.amount,
                );
                final myExpensesCount = expenses
                    .where((e) => e.payerId == currentUserId)
                    .length;
                final othersCount = expenses.length - myExpensesCount;

                return _buildGroupInfoContainer(
                  context,
                  groupName: groupsProvider.currentGroupName ?? 'Group Name',
                  statusText: statusText,
                  statusColor: statusColor,
                  totalCount: expenses.length,
                  myCount: myExpensesCount,
                  othersCount: othersCount,
                  totalAmount: totalAmount,
                  currency: currency,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGroupInfoContainer(
    BuildContext context, {
    required String groupName,
    required String statusText,
    required Color statusColor,
    int? totalCount,
    int? myCount,
    int? othersCount,
    double? totalAmount,
    String? currency,
  }) {
    final hasStats =
        totalCount != null &&
        myCount != null &&
        othersCount != null &&
        totalAmount != null &&
        currency != null;

    return Container(
      color: Colors.grey[300],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppTheme.background),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  groupName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamilyDisplay,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (hasStats)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeaderStatChip(
                  Icons.receipt_long,
                  '$totalCount',
                  'Total',
                ),
                const SizedBox(width: 6),
                _buildHeaderStatChip(Icons.person, '$myCount', 'Mine'),
                const SizedBox(width: 6),
                _buildHeaderStatChip(Icons.people, '$othersCount', 'Others'),
                const SizedBox(width: 6),
                _buildHeaderStatChip(
                  Icons.attach_money,
                  '${totalAmount.toStringAsFixed(0)}',
                  currency,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatChip(IconData icon, String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.secondaryDark),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 8, color: AppTheme.secondaryDark),
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
  final String? groupName;

  const GroupBalanceStatusWidget({
    super.key,
    required this.groupId,
    required this.currency,
    this.groupName,
  });

  @override
  Widget build(BuildContext context) {
    final balanceService = BalanceService();
    final firestoreService = FirestoreService();

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final currentUserId = authProvider.currentUserId;

        if (currentUserId == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '—',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textDark,
                ),
              ),
            ],
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '—',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              );
            }

            final expenses = expenseSnapshot.data!.docs
                .map((doc) => Expense.fromFirestore(doc))
                .toList();

            return FutureBuilder<List<GroupMember>>(
              future: firestoreService.getGroupMembers(groupId),
              builder: (context, memberSnapshot) {
                if (!memberSnapshot.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '—',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  );
                }

                final members = memberSnapshot.data!;
                final balances = balanceService.calculateNetBalances(
                  expenses,
                  members,
                );
                final myBalance = balances[currentUserId] ?? 0.0;

                final isPositive = myBalance > 0.01;
                final isNegative = myBalance < -0.01;

                String statusText;
                String amountText;
                Color statusColor;

                final displayGroupName = groupName ?? 'Group';

                if (isPositive) {
                  statusText = '$displayGroupName owes you';
                  amountText = '${myBalance.toStringAsFixed(0)} $currency';
                  statusColor = AppTheme.secondaryDark;
                } else if (isNegative) {
                  statusText = 'You owe $displayGroupName';
                  amountText = '${(-myBalance).toStringAsFixed(0)} $currency';
                  statusColor = AppTheme.primaryDark;
                } else {
                  statusText = 'Settled up';
                  amountText = '';
                  statusColor = AppTheme.textDark;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textDark,
                      ),
                    ),
                    if (amountText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        amountText,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
