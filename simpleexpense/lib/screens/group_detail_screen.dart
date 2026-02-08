import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/screens/add_expense_screen.dart';
import 'package:simpleexpense/screens/expense_detail_screen.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'package:simpleexpense/screens/widgets/expense_widgets.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
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
            backgroundColor: AppTheme.darkGray,
            body: SafeArea(
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.white),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.darkGray,
          body: SafeArea(
            child: Column(
              children: [
                const ExpenseHeaderWidget(),
                const GroupInfoWidget(),
                // Main content area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(color: AppTheme.white),
                    child: _buildExpensesView(context, groupsProvider),
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

        final expensesList = snapshot.data!.docs.map((doc) {
          return {
            'description': doc['description'] ?? '',
            'amount': doc['amount'] ?? 0.0,
            'payer': doc['payerId'] ?? '',
          };
        }).toList();

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
                  decoration: BoxDecoration(color: AppTheme.darkGray),
                  child: const Icon(Icons.add, color: AppTheme.white, size: 60),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ' Add Expense',
                style: TextStyle(
                  color: AppTheme.darkGray,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          );
        }

        final totalBalance = expensesList.fold(
          0.0,
          (sum, expense) => sum + (expense['amount'] as num),
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
                  final description = expense['description'] as String;
                  final amount = double.parse(expense['amount'].toString());
                  final payerId = expense['payer'] as String;
                  final currency = groupsProvider.currentCurrency ?? 'SEK';

                  return _buildExpenseItem(
                    context,
                    description,
                    '$amount $currency',
                    amount,
                    payerId,
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

  Widget _buildExpenseItem(
    BuildContext context,
    String title,
    String amount,
    double rawAmount,
    String payerId,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExpenseDetailScreen(
              description: title,
              amount: rawAmount,
              payerId: payerId,
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
      ),
    );
  }

  void _navigateToAddExpense(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
  }
}
