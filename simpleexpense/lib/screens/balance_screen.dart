import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/auth_provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/services/balance_service.dart';
import 'package:simpleexpense/services/firestore_service.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'package:simpleexpense/screens/widgets/expense_widgets.dart';
import '../models/models.dart';

/// Screen displaying net balances and settlement suggestions
class BalanceScreen extends StatefulWidget {
  final String groupId;

  const BalanceScreen({super.key, required this.groupId});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  final BalanceService _balanceService = BalanceService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupsProvider>().selectGroup(widget.groupId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupsProvider>(
      builder: (context, groupsProvider, child) {
        final isGroupLoaded =
            groupsProvider.currentGroupId == widget.groupId &&
                groupsProvider.selectedGroup != null;

        if (!isGroupLoaded) {
          return Scaffold(
            backgroundColor: AppTheme.primary,
            body: SafeArea(
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.textLight),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.primary,
          body: SafeArea(
            child: Column(
              children: [
                const ExpenseHeaderWidget(),
                const GroupInfoWidget(),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: AppTheme.textLight,
                    child: _buildBalanceView(context, groupsProvider),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceView(
    BuildContext context,
    GroupsProvider groupsProvider,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(groupsProvider.currentGroupId)
          .collection('expenses')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading balances',
              style: TextStyle(color: AppTheme.primary),
            ),
          );
        }

        // Convert to expenses
        final expenses = snapshot.data?.docs
            .map((doc) => Expense.fromFirestore(doc))
            .toList() ?? [];

        return FutureBuilder<List<GroupMember>>(
          future: _firestoreService.getGroupMembers(widget.groupId),
          builder: (context, memberSnapshot) {
            if (!memberSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }

            final members = memberSnapshot.data!;
            final balances = _balanceService.calculateNetBalances(expenses, members);
            final settlements = _balanceService.calculateSettlements(balances);
            final currentUserId = context.read<AuthProvider>().currentUserId;
            final currency = groupsProvider.currentCurrency ?? 'SEK';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Net Balances'),
                  const SizedBox(height: 12),
                  _buildBalancesList(balances, members, currentUserId, currency),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Suggested Settlements'),
                  const SizedBox(height: 12),
                  settlements.isEmpty
                      ? _buildAllSettledCard()
                      : _buildSettlementsList(settlements, members, currency),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.primary,
      ),
    );
  }

  Widget _buildBalancesList(
    Map<String, double> balances,
    List<GroupMember> members,
    String? currentUserId,
    String currency,
  ) {
    // Sort members by balance (highest to lowest)
    final sortedMembers = members.toList()
      ..sort((a, b) {
        final balanceA = balances[a.uid] ?? 0;
        final balanceB = balances[b.uid] ?? 0;
        return balanceB.compareTo(balanceA);
      });

    return Column(
      children: sortedMembers.map((member) {
        final balance = balances[member.uid] ?? 0;
        final isCurrentUser = member.uid == currentUserId;
        
        return _buildBalanceCard(
          member.name,
          balance,
          currency,
          isCurrentUser,
        );
      }).toList(),
    );
  }

  Widget _buildBalanceCard(
    String name,
    double balance,
    String currency,
    bool isCurrentUser,
  ) {
    final isPositive = balance > 0.01;
    final isNegative = balance < -0.01;
    final isSettled = !isPositive && !isNegative;

    Color cardColor = Colors.grey.shade100;
    Color textColor = AppTheme.textDark;
    String statusText = 'Settled up';
    IconData icon = Icons.check_circle;

    if (isPositive) {
      cardColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      statusText = 'Gets back';
      icon = Icons.arrow_upward;
    } else if (isNegative) {
      cardColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
      statusText = 'Owes';
      icon = Icons.arrow_downward;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? AppTheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? 'You' : name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryDark,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${balance.abs().toStringAsFixed(2)} $currency',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllSettledCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration, color: Colors.green.shade700, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Settled Up!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Everyone is even in this group',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementsList(
    List<Settlement> settlements,
    List<GroupMember> members,
    String currency,
  ) {
    final currentUserId = context.read<AuthProvider>().currentUserId;

    return Column(
      children: settlements.map((settlement) {
        final fromMember = members.firstWhere(
          (m) => m.uid == settlement.fromUserId,
          orElse: () => GroupMember(
            uid: settlement.fromUserId,
            name: 'Unknown',
            email: '',
          ),
        );
        final toMember = members.firstWhere(
          (m) => m.uid == settlement.toUserId,
          orElse: () => GroupMember(
            uid: settlement.toUserId,
            name: 'Unknown',
            email: '',
          ),
        );

        final isUserInvolved = settlement.fromUserId == currentUserId ||
            settlement.toUserId == currentUserId;

        return _buildSettlementCard(
          fromMember.name,
          toMember.name,
          settlement.amount,
          currency,
          isUserInvolved,
          settlement.fromUserId == currentUserId,
        );
      }).toList(),
    );
  }

  Widget _buildSettlementCard(
    String fromName,
    String toName,
    double amount,
    String currency,
    bool isUserInvolved,
    bool isUserPaying,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUserInvolved ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUserInvolved ? Colors.blue.shade200 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isUserPaying ? 'You' : fromName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: AppTheme.secondaryDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUserPaying ? toName : (isUserInvolved ? 'You' : toName),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${amount.toStringAsFixed(2)} $currency',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (isUserInvolved)
            ElevatedButton(
              onPressed: () {
                _showSettleUpDialog(fromName, toName, amount, currency);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('Settle'),
            ),
        ],
      ),
    );
  }

  void _showSettleUpDialog(
    String fromName,
    String toName,
    double amount,
    String currency,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settle Up'),
        content: Text(
          'Record that $fromName paid $toName ${amount.toStringAsFixed(2)} $currency?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement settlement recording
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settlement feature coming soon!'),
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}