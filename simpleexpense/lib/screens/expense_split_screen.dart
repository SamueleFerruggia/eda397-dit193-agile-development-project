import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/services/firestore_service.dart';
import 'package:simpleexpense/theme/app_theme.dart';

class ExpenseSplitScreen extends StatefulWidget {
  final String description;
  final double amount;
  final String payerId; // 'Me' or real UID

  const ExpenseSplitScreen({
    super.key,
    required this.description,
    required this.amount,
    required this.payerId,
  });

  @override
  State<ExpenseSplitScreen> createState() => _ExpenseSplitScreenState();
}

class _ExpenseSplitScreenState extends State<ExpenseSplitScreen> {
  bool _isLoading = false;

  // In future, we will support different split types (equally, by percentage, exact amounts)
  // For now, we will just implement "Split Equally" with checkboxes to include
  Set<String> _selectedMemberIds = {};

  @override
  void initState() {
    super.initState();
    // Select the members of the current group to initialize the checkboxes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final members =
          context.read<GroupsProvider>().selectedGroup?['members']
              as List<dynamic>?;
      if (members != null) {
        setState(() {
          _selectedMemberIds = members.map((e) => e.toString()).toSet();
        });
      }
    });
  }

  void _handleSave() async {
    setState(() => _isLoading = true);

    try {
      final groupsProvider = context.read<GroupsProvider>();
      final groupId = groupsProvider.currentGroupId;
      final currentUser = FirebaseAuth.instance.currentUser;

      if (groupId == null || currentUser == null)
        throw Exception("Error info missing");

      // Resolve who is the actual payer (if 'Me', use current user's UID)
      final actualPayerId = widget.payerId == 'Me'
          ? currentUser.uid
          : widget.payerId;

      await FirestoreService().addExpense(
        groupId: groupId,
        description: widget.description,
        amount: widget.amount,
        payerId: actualPayerId,
      );

      if (!mounted) return;
      // Back to the main screen (pop twice: first pop the split screen, then pop the add expense screen)
      Navigator.of(context).pop();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense saved!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsProvider = context.watch<GroupsProvider>();
    final currency = groupsProvider.currentCurrency ?? 'SEK';

    // Member's list of the currently selected group
    final members =
        groupsProvider.selectedGroup?['members'] as List<dynamic>? ?? [];

    // Calculate division (Equally)
    final splitAmount = _selectedMemberIds.isEmpty
        ? 0.0
        : widget.amount / _selectedMemberIds.length;

    return Scaffold(
      backgroundColor: AppTheme.lightGray,
      appBar: AppBar(
        title: const Text(
          'Add expense',
          style: TextStyle(color: AppTheme.darkGray),
        ),
        backgroundColor: AppTheme.lightGray,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.darkGray),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: AppTheme.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Splitting',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${widget.amount.toStringAsFixed(2)} $currency',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Members list with checkboxes to include in the split
                  Expanded(
                    child: ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final memberId = members[index].toString();
                        // Here we should ideally fetch the user's name using the memberId,
                        //but for simplicity we'll just show "Me" or a placeholder
                        final isMe =
                            memberId == FirebaseAuth.instance.currentUser?.uid;
                        final displayName = isMe
                            ? "Me"
                            : "User...${memberId.substring(0, 4)}";
                        final isSelected = _selectedMemberIds.contains(
                          memberId,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: CheckboxListTile(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(displayName),
                                Text(
                                  isSelected
                                      ? '${splitAmount.toStringAsFixed(0)} $currency'
                                      : '0 $currency',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            value: isSelected,
                            activeColor: AppTheme.darkGray,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedMemberIds.add(memberId);
                                } else {
                                  _selectedMemberIds.remove(memberId);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  // Split button (UI Only for now)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          child: const Text(
                            'Split equally',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // In future, we will add more split options (by percentage, exact amounts, etc.)
                ],
              ),
            ),
          ),

          // SAVE button
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.white,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkGray,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
