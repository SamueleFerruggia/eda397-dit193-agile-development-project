import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/services/firestore_service.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import '../models/models.dart';
import 'expense_split_screen.dart';

class AddExpenseScreen extends StatefulWidget {
  final bool embedInParent;

  const AddExpenseScreen({super.key, this.embedInParent = false});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoadingMembers = true;
  List<GroupMember> _members = [];
  String? _paidById;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final groupId = context.read<GroupsProvider>().currentGroupId;
    if (groupId == null) {
      if (mounted) setState(() => _isLoadingMembers = false);
      return;
    }

    try {
      final members = await _firestoreService.getGroupMembers(groupId);
      final currentUser = FirebaseAuth.instance.currentUser;
      String? defaultPayerId = currentUser?.uid;

      if (defaultPayerId == null && members.isNotEmpty) {
        defaultPayerId = members.first.uid;
      }

      if (mounted) {
        setState(() {
          _members = members;
          _paidById = defaultPayerId;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading members: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _handleNext() {
    final description = _descriptionController.text.trim();
    final amountText = _amountController.text.trim();

    if (description.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter description and amount')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (_paidById == null || _paidById!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select who paid')),
      );
      return;
    }

    // Navigate to the ExpenseSplitScreen, passing the entered data
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseSplitScreen(
          description: description,
          amount: amount,
          payerId: _paidById!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<GroupsProvider>().currentCurrency ?? 'SEK';
    final currentUser = FirebaseAuth.instance.currentUser;

    final body = Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: AppTheme.background,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: 'What is this for?',
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.secondaryDark.withOpacity(0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTheme.secondaryDark.withOpacity(0.3)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        currency,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Paid by',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      border: Border.all(color: AppTheme.secondaryDark.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isLoadingMembers
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(),
                          )
                        : DropdownButton<String>(
                            value: _paidById,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            items: _members.map((member) {
                              final isMe = member.uid == currentUser?.uid;
                              final label =
                                  isMe ? 'Me (${member.name})' : member.name;
                              return DropdownMenuItem(
                                value: member.uid,
                                child: Text(label),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _paidById = val),
                          ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.background,
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleNext, // Call Next
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(fontSize: 16, color: AppTheme.textLight),
                ),
              ),
            ),
          ),
        ],
      );

    if (widget.embedInParent) {
      return Container(
        color: AppTheme.background,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Expense',
          style: TextStyle(
            color: AppTheme.textLight,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: body,
    );
  }
}
