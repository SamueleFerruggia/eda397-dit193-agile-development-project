import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/screens/add_expense_screen.dart';
import 'package:simpleexpense/theme/app_theme.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  String _sortType = 'Description'; // 'Description' or 'People'

  @override
  void initState() {
    super.initState();
    // Select the current group in the provider when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupsProvider>().selectGroup(widget.groupId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkGray,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildGroupInfo(context),
            // Main content area
            Expanded(
              child: Consumer<GroupsProvider>(
                builder: (context, groupsProvider, child) {
                  return Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(color: AppTheme.white),
                    // We delegate the logic (Empty vs List) to the _buildExpensesView
                    child: _buildExpensesView(context, groupsProvider),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays the empty state with a big Add button
  Widget _buildEmptyView() {
    return GestureDetector(
      onTap: () => _navigateToAddExpense(context),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.darkGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: AppTheme.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add Expense',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.darkGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Logic to fetch real data from Firestore
  Widget _buildExpensesView(
    BuildContext context,
    GroupsProvider groupsProvider,
  ) {
    final groupId = groupsProvider.currentGroupId;

    // Safety check
    if (groupId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // 1. Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. Error
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        // 3. No Data -> Show Empty View
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyView();
        }

        // 4. Data Exists -> Show List + Bottom Bar
        final expenses = snapshot.data!.docs;

        // Calculate total balance
        double totalBalance = 0;
        for (var expense in expenses) {
          final data = expense.data() as Map<String, dynamic>;
          final amount = data['amount'] as num? ?? 0;
          totalBalance += amount.toDouble();
        }

        // Create list of expenses
        List<Map<String, dynamic>> expensesList = [];
        for (var expense in expenses) {
          final data = expense.data() as Map<String, dynamic>;
          expensesList.add({
            'id': expense.id,
            'description': data['description'] ?? 'No description',
            'amount': data['amount'] ?? 0,
            'payerId': data['payerId'] ?? 'Unknown',
            'timestamp': data['timestamp'],
          });
        }

        // Sort expenses based on selected sort type
        _sortExpenses(expensesList);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Expenses list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                itemCount: expensesList.length,
                itemBuilder: (context, index) {
                  final expense = expensesList[index];
                  final description = expense['description'] as String;
                  final amount = expense['amount'].toString();
                  final currency = groupsProvider.currentCurrency ?? 'SEK';

                  return _buildExpenseItem(description, '$amount $currency');
                },
              ),
            ),
            // Bottom bar with sort and add button
            _buildBottomBar(context, totalBalance, groupsProvider),
          ],
        );
      },
    );
  }

  /// Sort expenses based on the selected sort type
  void _sortExpenses(List<Map<String, dynamic>> expenses) {
    if (_sortType == 'Description') {
      expenses.sort((a, b) {
        final descA = a['description'] as String;
        final descB = b['description'] as String;
        return descA.compareTo(descB);
      });
    } else if (_sortType == 'People') {
      expenses.sort((a, b) {
        final payerA = a['payer'] as String;
        final payerB = b['payer'] as String;
        return payerA.compareTo(payerB);
      });
    }
  }

  /// extracted Bottom Bar widget for cleaner code
  Widget _buildBottomBar(
    BuildContext context,
    double totalBalance,
    GroupsProvider groupsProvider,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.lightGray,
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButton<String>(
                value: _sortType,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                    value: 'Description',
                    child: Text(
                      'Sort by Description',
                      style: TextStyle(fontSize: 14, color: AppTheme.darkGray),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'People',
                    child: Text(
                      'Sort by People',
                      style: TextStyle(fontSize: 14, color: AppTheme.darkGray),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _sortType = value;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.darkGray,
              borderRadius: BorderRadius.circular(4),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _navigateToAddExpense(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(String title, String amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey[400]!, width: 8)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.lightGray,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.receipt, color: AppTheme.middleGray),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Consumer<GroupsProvider>(
        builder: (context, groupsProvider, child) {
          final inviteCode = groupsProvider.currentInviteCode ?? '------';

          return Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (inviteCode != '------') {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invite code copied to clipboard'),
                        duration: Duration(milliseconds: 1500),
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
                        color: AppTheme.middleGray,
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
                            color: AppTheme.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.content_copy,
                          color: AppTheme.white,
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

  Widget _buildGroupInfo(BuildContext context) {
    return Consumer<GroupsProvider>(
      builder: (context, groupsProvider, child) {
        return Container(
          color: Colors.grey[300],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppTheme.lightGray),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupsProvider.currentGroupName ?? 'Group Name',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${groupsProvider.currentGroupTotalBalance.toStringAsFixed(2)} ${groupsProvider.currentCurrency ?? 'SEK'}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToAddExpense(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
  }
}
