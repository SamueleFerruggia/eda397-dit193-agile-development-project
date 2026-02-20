import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/services/firestore_service.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import '../models/models.dart';

class ExpenseSplitScreen extends StatefulWidget {
  final String description;
  final double amount;
  final String payerId;

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
  bool _isSaving = false;
  bool _isLoadingMembers = true;
  List<GroupMember> _members = [];
  Map<String, double> _splitAmounts = {}; // userId -> amount
  Map<String, TextEditingController> _controllers = {}; // userId -> controller
  bool _useEqualSplit = true;

  @override
  void initState() {
    super.initState();
    _loadGroupMembers();
  }

  Future<void> _loadGroupMembers() async {
    final provider = context.read<GroupsProvider>();
    final groupId = provider.currentGroupId;

    if (groupId != null) {
      try {
        final members = await FirestoreService().getGroupMembers(groupId);
        if (mounted) {
          setState(() {
            _members = members;
            // Initialize equal split among all members
            final equalAmount = widget.amount / members.length;
            for (final member in members) {
              _splitAmounts[member.uid] = equalAmount;
              _controllers[member.uid] = TextEditingController(
                text: equalAmount.toStringAsFixed(2),
              );
            }
            _isLoadingMembers = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingMembers = false);
      }
    }
  }

  void _splitEqually() {
    final equalAmount = widget.amount / _members.length;
    setState(() {
      _useEqualSplit = true;
      for (final member in _members) {
        _splitAmounts[member.uid] = equalAmount;
        _controllers[member.uid]?.text = equalAmount.toStringAsFixed(2);
      }
    });
  }

  void _updateAmount(String memberId, String value) {
    final amount = double.tryParse(value) ?? 0.0;
    setState(() {
      _useEqualSplit = false;
      _splitAmounts[memberId] = amount;
    });
  }

  double _getTotalSplit() {
    return _splitAmounts.values.fold(0.0, (sum, amount) => sum + amount);
  }

  bool _isValidSplit() {
    final total = _getTotalSplit();
    return (total - widget.amount).abs() < 0.01; // Allow for floating point errors
  }

  void _handleSave() async {
    if (!_isValidSplit()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Split amounts must equal ${widget.amount.toStringAsFixed(2)}. Current total: ${_getTotalSplit().toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final groupsProvider = context.read<GroupsProvider>();
      final groupId = groupsProvider.currentGroupId;

      if (groupId == null) {
        throw Exception("Error info missing");
      }

      // Only include members with amounts > 0
      final validSplits = <String, double>{};
      _splitAmounts.forEach((userId, amount) {
        if (amount > 0) {
          validSplits[userId] = amount;
        }
      });

      if (validSplits.isEmpty) {
        throw Exception("At least one person must have an amount assigned");
      }

      await FirestoreService().addExpense(
        groupId: groupId,
        description: widget.description,
        amount: widget.amount,
        payerId: widget.payerId,
        splitAmounts: validSplits,
      );

      if (!mounted) return;

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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsProvider = context.watch<GroupsProvider>();
    final currency = groupsProvider.currentCurrency ?? 'SEK';
    final currentUser = FirebaseAuth.instance.currentUser;
    final totalSplit = _getTotalSplit();
    final difference = (totalSplit - widget.amount).abs();
    final isValid = difference < 0.01;

    return Scaffold(
      backgroundColor: AppTheme.lightGray,
      appBar: AppBar(
        title: const Text(
          'Split Expense',
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'How to split?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.amount.toStringAsFixed(2)} $currency',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGray,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Equal split button
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _splitEqually,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _useEqualSplit ? AppTheme.darkGray : Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(
                        'Split Equally',
                        style: TextStyle(
                          color: _useEqualSplit ? Colors.white : Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Member list with custom amounts
                  Expanded(
                    child: _isLoadingMembers
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _members.length,
                                  itemBuilder: (context, index) {
                                    final member = _members[index];
                                    final isMe = member.uid == currentUser?.uid;
                                    final displayName = isMe
                                        ? "Me (${member.name})"
                                        : member.name;
                                    final controller =
                                        _controllers[member.uid]!;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.darkGray,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: controller,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                              decimal: true,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: '0.00',
                                              suffix: Text(
                                                ' $currency',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                borderSide: const BorderSide(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
                                            onChanged: (value) =>
                                                _updateAmount(member.uid, value),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isValid
                                        ? Colors.green[50]
                                        : Colors.red[50],
                                    border: Border.all(
                                      color: isValid
                                          ? Colors.green[300]!
                                          : Colors.red[300]!,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${totalSplit.toStringAsFixed(2)} / ${widget.amount.toStringAsFixed(2)} $currency',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isValid
                                              ? Colors.green[700]
                                              : Colors.red[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.white,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving || !isValid ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid ? AppTheme.darkGray : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
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
