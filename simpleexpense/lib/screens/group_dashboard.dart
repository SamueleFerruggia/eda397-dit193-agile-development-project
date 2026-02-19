import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/screens/add_expense_screen.dart';
import 'package:simpleexpense/screens/expense_detail_screen.dart';
import 'package:simpleexpense/screens/expense_list_screen.dart';
import 'package:simpleexpense/screens/balance_screen.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'package:simpleexpense/screens/widgets/expense_widgets.dart';
import '../models/models.dart'; // Import models

class GroupDashboardScreen extends StatefulWidget {
  final String groupId;

  const GroupDashboardScreen({super.key, required this.groupId});

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  String _sortType = 'Description';

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
                // Main content area - Show buttons instead of expense list
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(color: AppTheme.textLight),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // My Expenses Button
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ExpenseListScreen(groupId: widget.groupId),
                                ),
                              );
                            },
                            icon: const Icon(Icons.list_alt, size: 32),
                            label: const Text(
                              'My Expenses',
                              style: TextStyle(fontSize: 18),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Balances Button
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BalanceScreen(groupId: widget.groupId),
                                ),
                              );
                            },
                            icon: const Icon(Icons.account_balance_wallet, size: 32),
                            label: const Text(
                              'Balances',
                              style: TextStyle(fontSize: 18),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Add Expense Button
                          ElevatedButton.icon(
                            onPressed: () => _navigateToAddExpense(context),
                            icon: const Icon(Icons.add, size: 32),
                            label: const Text(
                              'Add Expense',
                              style: TextStyle(fontSize: 18),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpensesView(
    BuildContext context,
    GroupsProvider groupsProvider,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(groupsProvider.currentGroupId)
          .collection('expenses')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Convert Firestore documents to Expense objects
        final expensesList = snapshot.data!.docs
            .map((doc) => Expense.fromFirestore(doc))
            .toList();

        if (expensesList.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _navigateToAddExpense(context),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(color: AppTheme.primary),
                  child: const Icon(Icons.add, color: AppTheme.textLight, size: 60),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ' Add Expense',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          );
        }

        // Calculate total balance using the Expense model
        final totalBalance = expensesList.fold(
          0.0,
          (sum, expense) => sum + expense.amount,
        );

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                itemCount: expensesList.length,
                itemBuilder: (context, index) {
                  final expense = expensesList[index];
                  final currency = groupsProvider.currentCurrency ?? 'SEK';

                  return _buildExpenseItem(
                    context,
                    expense.description,
                    '${expense.amount.toStringAsFixed(2)} $currency',
                    expense.amount,
                    expense.payerId,
                    expense.splitWith, // Pass split info
                  );
                },
              ),
            ),
            _buildBottomBar(context, totalBalance, groupsProvider),
          ],
        );
      },
    );
  }

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
                color: AppTheme.background,
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
                      style: TextStyle(fontSize: 14, color: AppTheme.textDark),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'People',
                    child: Text(
                      'Sort by People',
                      style: TextStyle(fontSize: 14, color: AppTheme.textDark),
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
              color: AppTheme.primary,
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

  Widget _buildExpenseItem(
    BuildContext context,
    String title,
    String amountString,
    double rawAmount,
    String payerId,
    List<String> splitWith, // Added parameter
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExpenseDetailScreen(
              description: title,
              amount: rawAmount,
              payerId: payerId,
              splitWith: splitWith, // Pass to details
            ),
          ),
        );
      },
      child: Container(
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
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.receipt, color: AppTheme.secondaryDark),
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
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    amountString,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAddExpense(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
  }
}