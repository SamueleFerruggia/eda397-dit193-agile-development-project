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


  Widget settleRequestCard(SettleRequest req) {
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
                            Text('Amount: ${req.amount.toStringAsFixed(2)}'),
                            if (sentTime.isNotEmpty) Text(sentTime),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    await _firestoreService.updateSettleRequestStatus(req.id, 'accepted');
                                    if (!mounted) return;
                                    innerSetState(() => dismissed = true);
                                    // Execute the actual balance settlement
                                    await _executeSettlement(req.fromUserId, req.toUserId);
                                  },
                                  child: const Text('Approve'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () async {
                                    await _firestoreService.updateSettleRequestStatus(req.id, 'declined');
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
            final settlements = _balanceService.calculateSettlements(balances);
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
                          children: requests.map((req) => settleRequestCard(req)).toList(),
                        );
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Suggested Settlements'),
                  const SizedBox(height: 12),
                  settlements.isEmpty
                      ? _buildAllSettledCard()
                      : _buildSettlementsList(settlements, members, currency),
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
          settlement.fromUserId,
          settlement.toUserId,
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
    String fromUserId,
    String toUserId,
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
                _showSettleUpDialog(
                  fromName, toName, amount, currency, fromUserId, toUserId,
                );
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
    String fromUserId,
    String toUserId,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Settle Up'),
        content: Text(
          'Record that $fromName paid $toName ${amount.toStringAsFixed(2)} $currency?\n\n'
          'This will archive the shared expenses between these two users and reset their balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _executeSettlement(fromUserId, toUserId);
            },
            child: const Text('Confirm'),
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

  // TEMP DEBUG FEATURE – REMOVE BEFORE PRODUCTION
  /// Shows a dialog listing all suggested settlements and lets the developer
  /// force-trigger any of them without the real voting flow.
  /// When no settlements exist, allows picking any two members to settle.
  void _showDebugSettleDialog(
    List<Settlement> settlements,
    List<GroupMember> members,
    String currency,
  ) {
    if (settlements.isNotEmpty) {
      // Show suggested settlements
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('DEBUG: Force Settlement'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: settlements.length,
              itemBuilder: (_, i) {
                final s = settlements[i];
                final from = members
                    .firstWhere(
                      (m) => m.uid == s.fromUserId,
                      orElse: () =>
                          GroupMember(uid: s.fromUserId, name: 'Unknown', email: ''),
                    )
                    .name;
                final to = members
                    .firstWhere(
                      (m) => m.uid == s.toUserId,
                      orElse: () =>
                          GroupMember(uid: s.toUserId, name: 'Unknown', email: ''),
                    )
                    .name;
                return ListTile(
                  title: Text('$from → $to'),
                  subtitle: Text('${s.amount.toStringAsFixed(2)} $currency'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _executeSettlement(s.fromUserId, s.toUserId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Settle'),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      // No settlements — let dev pick any two members
      _showDebugPickMembersDialog(members);
    }
  }

  /// When balances are already zero but expenses exist, let the developer
  /// pick two members to force-archive their shared expenses.
  void _showDebugPickMembersDialog(List<GroupMember> members) {
    if (members.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 members to settle.')),
      );
      return;
    }

    String? selectedA;
    String? selectedB;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('DEBUG: Pick Two Members'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No outstanding settlements. Pick any two members to '
                  'archive their shared expenses.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Member A'),
                  value: selectedA,
                  items: members
                      .map((m) => DropdownMenuItem(
                            value: m.uid,
                            child: Text(m.name),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedA = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Member B'),
                  value: selectedB,
                  items: members
                      .where((m) => m.uid != selectedA)
                      .map((m) => DropdownMenuItem(
                            value: m.uid,
                            child: Text(m.name),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedB = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: (selectedA != null && selectedB != null)
                    ? () {
                        Navigator.pop(dialogContext);
                        _executeSettlement(selectedA!, selectedB!);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Force Settle'),
              ),
            ],
          );
        },
      ),
    );
  }
  // END TEMP DEBUG FEATURE
}