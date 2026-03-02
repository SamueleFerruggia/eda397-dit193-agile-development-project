import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/models/models.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/screens/expense_list_screen.dart';
import 'package:simpleexpense/screens/balance_screen.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'package:simpleexpense/screens/widgets/expense_widgets.dart';

class GroupDashboardScreen extends StatefulWidget {
  final String groupId;

  const GroupDashboardScreen({super.key, required this.groupId});

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  int _selectedIndex = 0;
  final ValueNotifier<List<Expense>?> _expensesForExport =
      ValueNotifier<List<Expense>?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupsProvider>().selectGroup(widget.groupId);
    });
  }

  @override
  void dispose() {
    _expensesForExport.dispose();
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
                ExpenseHeaderWidget(expensesForExport: _expensesForExport),
                const GroupInfoWidget(),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      ExpenseListScreen(
                        groupId: widget.groupId,
                        embedInParent: true,
                        expensesForExport: _expensesForExport,
                      ),
                      BalanceScreen(
                        groupId: widget.groupId,
                        embedInParent: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            color: AppTheme.textLight,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.list_alt, 'Expenses'),
                    _buildNavItem(1, Icons.account_balance_wallet, 'Balances'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppTheme.primary : AppTheme.secondaryDark,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.secondaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}