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
  Set<String> _selectedMemberIds = {};

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
            _selectedMemberIds = members.map((m) => m.uid).toSet();
            _isLoadingMembers = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingMembers = false);
      }
    }
  }

  void _handleSave() async {
    setState(() => _isSaving = true);

    try {
      final groupsProvider = context.read<GroupsProvider>();
      final groupId = groupsProvider.currentGroupId;
      final currentUser = FirebaseAuth.instance.currentUser;

      if (groupId == null || currentUser == null) {
        throw Exception("Error info missing");
      }

      final actualPayerId = widget.payerId == 'Me'
          ? currentUser.uid
          : widget.payerId;

      await FirestoreService().addExpense(
        groupId: groupId,
        description: widget.description,
        amount: widget.amount,
        payerId: actualPayerId,
        splitWith: _selectedMemberIds.toList(), // Pass selected members
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
  Widget build(BuildContext context) {
    final groupsProvider = context.watch<GroupsProvider>();
    final currency = groupsProvider.currentCurrency ?? 'SEK';
    final currentUser = FirebaseAuth.instance.currentUser;

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

                  Expanded(
                    child: _isLoadingMembers
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: _members.length,
                            itemBuilder: (context, index) {
                              final member = _members[index];
                              final isMe = member.uid == currentUser?.uid;
                              
                              final displayName = isMe ? "Me (${member.name})" : member.name;
                              final isSelected = _selectedMemberIds.contains(member.uid);

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
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.darkGray
                                        ),
                                      ),
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
                                        _selectedMemberIds.add(member.uid);
                                      } else {
                                        _selectedMemberIds.remove(member.uid);
                                      }
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),

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
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkGray,
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