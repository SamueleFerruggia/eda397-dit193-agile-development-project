import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/auth_provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/services/balance_service.dart';
import 'package:simpleexpense/services/firestore_service.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'package:simpleexpense/screens/widgets/expense_widgets.dart';
import 'package:simpleexpense/screens/archived_settlements_screen.dart';
import '../models/settle_request.dart';
import '../models/models.dart';

/// Screen displaying net balances and settlement suggestions
class BalanceScreen extends StatefulWidget {
  final String groupId;
  final bool embedInParent;

  const BalanceScreen({
    super.key,
    required this.groupId,
    this.embedInParent = false,
  });

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


  Widget settleRequestCard(SettleRequest req, String currency) {
    return StatefulBuilder(
      builder: (context, setState) {
        // Use a local state variable to track dismissal
        return StatefulBuilder(
          builder: (context, innerSetState) {
            bool dismissed = false;
            return AnimatedBuilder(
              animation: Listenable.merge([]),
              builder: (context, _) {
                if (dismissed) return const SizedBox.shrink();
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(req.fromUserId).get(),
                  builder: (context, userSnapshot) {
                    String fromName = req.fromUserId;
                    if (userSnapshot.connectionState == ConnectionState.done && userSnapshot.hasData && userSnapshot.data!.exists) {
                      final data = userSnapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null && data['name'] != null) {
                        fromName = data['name'];
                      }
                    }
                    String sentTime = '';
                    final date = req.createdAt;
                    sentTime = 'Sent: ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                                        return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('From: $fromName', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Amount: ${req.amount.toStringAsFixed(2)} $currency'),
                            if (sentTime.isNotEmpty) Text(sentTime),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    // First mark the request as accepted
                                    await _firestoreService.updateSettleRequestStatus(req.id, 'accepted');
                                    if (!mounted) return;
                                    // Execute the actual balance settlement
                                    await _executeSettlement(req.fromUserId, req.toUserId);
                                    if (!mounted) return;
                                    // Notify requester that their settlement was accepted
                                    await _firestoreService.addNotification(
                                      userId: req.fromUserId,
                                      message: 'Your settlement request for ${req.amount.toStringAsFixed(2)} $currency was accepted.',
                                      type: NotificationType.settlement,
                                    );
                                    if (!mounted) return;
                                    // Dismiss the card after settlement completes
                                    innerSetState(() => dismissed = true);
                                  },
                                  child: const Text('Approve'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () async {
                                    await _firestoreService.updateSettleRequestStatus(req.id, 'declined');
                                    if (!mounted) return;
                                    // Notify requester that their settlement was declined
                                    await _firestoreService.addNotification(
                                      userId: req.fromUserId,
                                      message: 'Your settlement request for ${req.amount.toStringAsFixed(2)} $currency was declined.',
                                      type: NotificationType.settlement,
                                    );
                                    if (!mounted) return;
                                    innerSetState(() => dismissed = true);
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      const SnackBar(content: Text('Settlement declined.')),
                                    );
                                  },
                                  child: const Text('Decline'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
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


  final content = Container(
    width: double.infinity,
    height: double.infinity,
    color: AppTheme.textLight,
    child: Column(
      children: [
        Expanded(child: _buildBalanceView(context, groupsProvider)),
      ],
    ),
  );

        if (widget.embedInParent) {
          return SizedBox.expand(child: content);
        }

        return Scaffold(
          backgroundColor: AppTheme.primary,
          body: SafeArea(
            child: Column(
              children: [
                const ExpenseHeaderWidget(),
                const GroupInfoWidget(),
                Expanded(child: content),
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
            // Only consider balances for current group members
            final allSettled = members.every((m) => (balances[m.uid] ?? 0).abs() < 0.01);
            final currentUserId = context.read<AuthProvider>().currentUserId;
            final currency = groupsProvider.currentCurrency ?? 'SEK';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Net Balances'),
                  const SizedBox(height: 12),
                  if (allSettled)
                    _buildAllSettledCard()
                  else
                    _buildBalancesList(balances, members, currentUserId, currency),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Settlement Requests'),
                  const SizedBox(height: 12),
                  StreamBuilder<List<SettleRequest>>(
                    stream: _firestoreService.streamSettleRequestsForGroup(widget.groupId),
                    builder: (context, reqSnapshot) {
                      if (!reqSnapshot.hasData) {
                        return Text(
                          'No settlement requests yet.',
                          style: TextStyle(color: AppTheme.secondaryDark),
                        );
                      }
                        // Only show requests with status 'pending' and toUserId matching currentUserId
                        final requests = reqSnapshot.data!
                            .where((req) => req.status == 'pending' && req.toUserId == currentUserId)
                            .toList();
                        if (requests.isEmpty) {
                          return Text(
                            'No settlement requests yet.',
                            style: TextStyle(color: AppTheme.secondaryDark),
                          );
                        }
                        return Column(
                          children: requests.map((req) => settleRequestCard(req, currency)).toList(),
                        );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Link to archived settlements
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArchivedSettlementsScreen(
                              groupId: widget.groupId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('View Archived Settlements'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.secondaryDark,
                      ),
                    ),
                  ),
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

  /// Execute the settlement via the provider and show feedback
  Future<void> _executeSettlement(String userA, String userB) async {
    final groupsProvider = context.read<GroupsProvider>();

    try {
      final result = await groupsProvider.settleDebt(
        groupId: widget.groupId,
        userA: userA,
        userB: userB,
      );

      if (!mounted) return;

      if (result['settled'] == true) {
        final amount = (result['amount'] as num).toDouble();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Settlement complete — ${amount.toStringAsFixed(2)} settled.',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['reason'] as String? ?? 'Nothing to settle.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settlement failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

}