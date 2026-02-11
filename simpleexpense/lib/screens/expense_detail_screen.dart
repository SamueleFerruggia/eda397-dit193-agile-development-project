import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'package:simpleexpense/screens/widgets/expense_widgets.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final String description;
  final double amount;
  final String payerId;
  final List<String> splitWith; // List of members involved in the split

  const ExpenseDetailScreen({
    super.key,
    required this.description,
    required this.amount,
    required this.payerId,
    required this.splitWith,
  });

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  Set<String> _selectedMemberIds = {};

  @override
  void initState() {
    super.initState();
    // Initialize selection based on the saved split data
    _selectedMemberIds = widget.splitWith.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupsProvider>(
      builder: (context, groupsProvider, _) {
        // Get all group members to display the full list
        final members = groupsProvider.selectedGroup?.memberIds ?? [];
        final currency = groupsProvider.currentCurrency ?? 'SEK';
        final currentUser = FirebaseAuth.instance.currentUser;

        final splitAmount = _selectedMemberIds.isEmpty
            ? 0.0
            : widget.amount / _selectedMemberIds.length;

        return Scaffold(
          backgroundColor: AppTheme.darkGray,
          body: SafeArea(
            child: Column(
              children: [
                const ExpenseHeaderWidget(),
                const GroupInfoWidget(),
                // Main content
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(color: AppTheme.white),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),

                          // Expense item
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                left: BorderSide(
                                  color: Colors.grey[400]!,
                                  width: 8,
                                ),
                              ),
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
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.description,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.darkGray,
                                  ),
                                ),
                                Text(
                                  '${widget.amount.toStringAsFixed(0)} $currency',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkGray,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Info section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Total amount: ${widget.amount.toStringAsFixed(0)} $currency\n'
                              'Paid by: ${widget.payerId == currentUser?.uid ? 'Me' : 'Someone else'}\n'
                              'Split: equally',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.darkGray,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Members section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: members.length,
                                  itemBuilder: (context, index) {
                                    final memberId = members[index];
                                    final isMe = memberId == currentUser?.uid;
                                    // Placeholder for name until we implement Member fetching in this screen
                                    final displayName = isMe ? 'Me' : 'User...${memberId.substring(0, 4)}';
                                    final isSelected = _selectedMemberIds.contains(memberId);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: isSelected,
                                              activeColor: AppTheme.darkGray,
                                              onChanged: null, // Read-only view
                                            ),
                                            Expanded(
                                              child: Text(
                                                displayName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: AppTheme.darkGray,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              isSelected
                                                  ? '${splitAmount.toStringAsFixed(0)} ${currency.substring(0, min(2, currency.length))}' 
                                                  : '0 $currency',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.darkGray,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Buttons
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: OutlinedButton(
                                    onPressed: () {},
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.grey),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: const Text(
                                      'Add People',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.darkGray,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: const Text(
                                      'Save changes',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
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
  
  // Helper for safe substring
  int min(int a, int b) => a < b ? a : b;
}