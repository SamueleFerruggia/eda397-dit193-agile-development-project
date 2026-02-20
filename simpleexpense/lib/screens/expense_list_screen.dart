import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/auth_provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/screens/add_expense_screen.dart';
import 'package:simpleexpense/screens/expense_detail_screen.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'package:simpleexpense/screens/widgets/expense_widgets.dart';
import '../models/models.dart';

/// Comprehensive Expense List Screen
/// Displays all expenses for a group with sorting, filtering, and search capabilities
class ExpenseListScreen extends StatefulWidget {
  final String groupId;

  const ExpenseListScreen({super.key, required this.groupId});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  String _sortType = 'Date (Newest)';
  String _filterType = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupsProvider>().selectGroup(widget.groupId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                _buildSearchBar(),
                // Main content area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: AppTheme.white,
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

  /// Search bar widget
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppTheme.darkGray),
        decoration: InputDecoration(
          hintText: 'Search expenses...',
          hintStyle: TextStyle(color: AppTheme.middleGray),
          prefixIcon: const Icon(Icons.search, color: AppTheme.darkGray),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.middleGray),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.lightGray,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.middleGray.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.middleGray.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.darkGray, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  /// Main expenses view with StreamBuilder
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.darkGray),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading expenses',
                  style: TextStyle(color: AppTheme.darkGray, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(color: AppTheme.middleGray, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(context);
        }

        // Convert Firestore documents to Expense objects
        List<Expense> expensesList = snapshot.data!.docs
            .map((doc) => Expense.fromFirestore(doc))
            .toList();

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          expensesList = expensesList.where((expense) {
            return expense.description.toLowerCase().contains(_searchQuery);
          }).toList();
        }

        // Apply user filter
        final currentUserId = context.read<AuthProvider>().currentUserId;
        if (_filterType == 'My Expenses' && currentUserId != null) {
          expensesList = expensesList.where((expense) {
            return expense.payerId == currentUserId;
          }).toList();
        } else if (_filterType == 'Others Expenses' && currentUserId != null) {
          expensesList = expensesList.where((expense) {
            return expense.payerId != currentUserId;
          }).toList();
        }

        // Apply sorting
        _sortExpenses(expensesList);

        // Calculate total balance
        final totalBalance = expensesList.fold(
          0.0,
          (sum, expense) => sum + expense.amount,
        );

        return Column(
          children: [
            _buildFilterChips(),
            _buildExpenseStats(expensesList, totalBalance, groupsProvider),
            Expanded(
              child: expensesList.isEmpty
                  ? _buildNoResultsState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: expensesList.length,
                      itemBuilder: (context, index) {
                        final expense = expensesList[index];
                        final currency = groupsProvider.currentCurrency ?? 'SEK';
                        final currentUserId = context.read<AuthProvider>().currentUserId;

                        return _buildExpenseItem(
                          context,
                          expense,
                          currency,
                          currentUserId,
                          groupsProvider,
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

  /// Filter chips for quick filtering
  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All'),
            const SizedBox(width: 8),
            _buildFilterChip('My Expenses'),
            const SizedBox(width: 8),
            _buildFilterChip('Others Expenses'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterType == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = label;
        });
      },
      backgroundColor: AppTheme.lightGray,
      selectedColor: AppTheme.darkGray,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.white : AppTheme.darkGray,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      checkmarkColor: AppTheme.white,
    );
  }

  /// Expense statistics summary
  Widget _buildExpenseStats(
    List<Expense> expenses,
    double totalBalance,
    GroupsProvider groupsProvider,
  ) {
    final currency = groupsProvider.currentCurrency ?? 'SEK';
    final currentUserId = context.read<AuthProvider>().currentUserId;
    
    final myExpenses = expenses.where((e) => e.payerId == currentUserId).length;
    final othersExpenses = expenses.length - myExpenses;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', '${expenses.length}', Icons.receipt_long),
          _buildStatItem('Mine', '$myExpenses', Icons.person),
          _buildStatItem('Others', '$othersExpenses', Icons.people),
          _buildStatItem(
            'Amount',
            '${totalBalance.toStringAsFixed(0)} $currency',
            Icons.attach_money,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.middleGray),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkGray,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.middleGray,
          ),
        ),
      ],
    );
  }

  /// Sort expenses based on selected sort type
  void _sortExpenses(List<Expense> expenses) {
    switch (_sortType) {
      case 'Date (Newest)':
        expenses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case 'Date (Oldest)':
        expenses.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case 'Amount (High to Low)':
        expenses.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'Amount (Low to High)':
        expenses.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case 'Description (A-Z)':
        expenses.sort((a, b) => a.description.compareTo(b.description));
        break;
      case 'Description (Z-A)':
        expenses.sort((a, b) => b.description.compareTo(a.description));
        break;
    }
  }

  /// Empty state when no expenses exist
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => _navigateToAddExpense(context),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.darkGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: AppTheme.white, size: 40),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No expenses yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGray,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the + button to add your first expense',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.middleGray,
            ),
          ),
        ],
      ),
    );
  }

  /// No results state when search/filter returns empty
  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: AppTheme.middleGray),
          const SizedBox(height: 16),
          const Text(
            'No expenses found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGray,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.middleGray,
            ),
          ),
        ],
      ),
    );
  }

  /// Individual expense item widget
  Widget _buildExpenseItem(
    BuildContext context,
    Expense expense,
    String currency,
    String? currentUserId,
    GroupsProvider groupsProvider,
  ) {
    final isPaidByMe = expense.payerId == currentUserId;
    
    // Format date without intl package
    final date = expense.timestamp;
    final formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final formattedTime = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    // Determine if paid by current user
    final payerName = isPaidByMe ? 'You' : 'Member';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExpenseDetailScreen(
              description: expense.description,
              amount: expense.amount,
              payerId: expense.payerId,
              splitAmounts: expense.splitAmounts,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            left: BorderSide(
              color: isPaidByMe ? Colors.green : Colors.blue,
              width: 4,
            ),
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPaidByMe
                      ? Colors.green.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPaidByMe ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isPaidByMe ? Colors.green : Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.description,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: AppTheme.middleGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Paid by $payerName',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.middleGray,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: AppTheme.middleGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$formattedDate at $formattedTime',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.middleGray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${expense.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPaidByMe ? Colors.green : Colors.blue,
                    ),
                  ),
                  Text(
                    currency,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.middleGray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGray,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Split ${expense.splitAmounts.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.middleGray,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom bar with sort dropdown and add button
  Widget _buildBottomBar(
    BuildContext context,
    double totalBalance,
    GroupsProvider groupsProvider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.lightGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _sortType,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.sort, color: AppTheme.darkGray),
                items: const [
                  DropdownMenuItem(
                    value: 'Date (Newest)',
                    child: Text('Date (Newest)'),
                  ),
                  DropdownMenuItem(
                    value: 'Date (Oldest)',
                    child: Text('Date (Oldest)'),
                  ),
                  DropdownMenuItem(
                    value: 'Amount (High to Low)',
                    child: Text('Amount (High to Low)'),
                  ),
                  DropdownMenuItem(
                    value: 'Amount (Low to High)',
                    child: Text('Amount (Low to High)'),
                  ),
                  DropdownMenuItem(
                    value: 'Description (A-Z)',
                    child: Text('Description (A-Z)'),
                  ),
                  DropdownMenuItem(
                    value: 'Description (Z-A)',
                    child: Text('Description (Z-A)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _sortType = value;
                    });
                  }
                },
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.darkGray,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.darkGray,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.darkGray.withOpacity(0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 28),
              onPressed: () => _navigateToAddExpense(context),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddExpense(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
    );
  }
}