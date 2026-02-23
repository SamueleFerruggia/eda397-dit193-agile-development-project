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
  final Map<String, double> _splitAmounts = {};
  final Map<String, TextEditingController> _controllers = {};
  String _splitMode = 'Equally'; // 'Equally', 'Exact Amount', 'Percentage'

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
            _splitEqually();
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
      _splitMode = 'Equally';
      for (final member in _members) {
        _splitAmounts[member.uid] = equalAmount;
        _controllers[member.uid] = TextEditingController(
          text: _formatAmount(equalAmount),
        );
      }
    });
  }

  void _updateSplitMode(String mode) {
    setState(() {
      _splitMode = mode;
      
      if (mode == 'Equally') {
        _splitEqually();
      } else if (mode == 'Percentage') {
        final equalPercentage = 100.0 / _members.length;
        for (final member in _members) {
          _controllers[member.uid]?.text = _formatAmount(equalPercentage);
          _splitAmounts[member.uid] = widget.amount * (equalPercentage / 100);
        }
      } else {
        // Exact Amount - keep current values or reset
        for (final member in _members) {
          if (!_controllers.containsKey(member.uid)) {
            _controllers[member.uid] = TextEditingController(text: '0');
            _splitAmounts[member.uid] = 0;
          }
        }
      }
    });
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  void _updateAmount(String memberId, String value) {
    final inputValue = double.tryParse(value) ?? 0.0;
    
    setState(() {
      if (_splitMode == 'Percentage') {
        _splitAmounts[memberId] = widget.amount * (inputValue / 100);
      } else {
        _splitAmounts[memberId] = inputValue;
      }
    });
  }

  double _getTotalSplit() {
    return _splitAmounts.values.fold(0.0, (sum, amount) => sum + amount);
  }

  double _getTotalPercentage() {
    if (_splitMode != 'Percentage') return 0.0;
    
    return _controllers.values.fold(0.0, (sum, controller) {
      return sum + (double.tryParse(controller.text) ?? 0.0);
    });
  }

  bool _isValidSplit() {
    if (_splitMode == 'Percentage') {
      final totalPercentage = _getTotalPercentage();
      return (totalPercentage - 100.0).abs() < 0.01;
    }
    
    final total = _getTotalSplit();
    return (total - widget.amount).abs() < 0.01;
  }

  void _handleSave() async {
    if (!_isValidSplit()) {
      String message;
      if (_splitMode == 'Percentage') {
        final totalPercentage = _getTotalPercentage();
        message = 'Percentages must equal 100%. Current total: ${_formatAmount(totalPercentage)}%';
      } else {
        message = 'Split amounts must equal ${_formatAmount(widget.amount)}. Current total: ${_formatAmount(_getTotalSplit())}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
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
    final isValid = _isValidSplit();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Add expense',
          style: TextStyle(
            color: AppTheme.textLight,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.background,
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
                  '${_formatAmount(widget.amount)} $currency',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 16),

                // Split mode selector using PopupMenuButton
                PopupMenuButton<String>(
                  offset: const Offset(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    _updateSplitMode(value);
                  },
                  itemBuilder: (BuildContext context) {
                    final List<PopupMenuEntry<String>> items = [];
                    
                    if (_splitMode != 'Equally') {
                      items.add(PopupMenuItem<String>(
                        value: 'Equally',
                        height: 56,
                        child: Row(
                          children: const [
                            Icon(Icons.balance, color: Color(0xFF7A9B76), size: 22),
                            SizedBox(width: 12),
                            Text(
                              'Split Equally',
                              style: TextStyle(fontSize: 15),
                            ),
                          ],
                        ),
                      ));
                    }
                    
                    if (_splitMode != 'Exact Amount') {
                      items.add(PopupMenuItem<String>(
                        value: 'Exact Amount',
                        height: 56,
                        child: Row(
                          children: const [
                            Icon(Icons.attach_money, color: Color(0xFF7A9B76), size: 22),
                            SizedBox(width: 12),
                            Text(
                              'Exact Amount',
                              style: TextStyle(fontSize: 15),
                            ),
                          ],
                        ),
                      ));
                    }
                    
                    if (_splitMode != 'Percentage') {
                      items.add(PopupMenuItem<String>(
                        value: 'Percentage',
                        height: 56,
                        child: Row(
                          children: const [
                            Icon(Icons.percent, color: Color(0xFF7A9B76), size: 22),
                            SizedBox(width: 12),
                            Text(
                              'Percentage',
                              style: TextStyle(fontSize: 15),
                            ),
                          ],
                        ),
                      ));
                    }
                    
                    return items;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A9B76),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _splitMode == 'Equally'
                                  ? Icons.balance
                                  : _splitMode == 'Exact Amount'
                                      ? Icons.attach_money
                                      : Icons.percent,
                              color: AppTheme.textLight,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _splitMode == 'Equally'
                                  ? 'Split Equally'
                                  : _splitMode == 'Exact Amount'
                                      ? 'Exact Amount'
                                      : 'Percentage',
                              style: const TextStyle(
                                color: AppTheme.textLight,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: AppTheme.textLight,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Member list with custom amounts
          Expanded(
            child: Container(
              color: AppTheme.background,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _isLoadingMembers
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final isMe = member.uid == currentUser?.uid;
                        final displayName = isMe
                            ? "Me (${member.name})"
                            : member.name;
                        final controller = _controllers[member.uid]!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            border: Border.all(
                              color: AppTheme.secondaryDark.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textDark,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: controller,
                                            keyboardType: const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                            readOnly: _splitMode == 'Equally',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: '0',
                                              filled: true,
                                              fillColor: _splitMode == 'Equally'
                                                  ? const Color(0xFFD7E6DA).withValues(alpha: 0.5)
                                                  : isValid
                                                    ? const Color(0xFFD7E6DA)
                                                    : const Color(0xFFFFCDD2),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide.none,
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              isDense: true,
                                            ),
                                            onChanged: (value) => _updateAmount(member.uid, value),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 45,
                                          child: Text(
                                            _splitMode == 'Percentage' ? '%' : currency,
                                            style: TextStyle(
                                              color: AppTheme.secondaryDark,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_splitMode == 'Percentage')
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '≈ ${_formatAmount(_splitAmounts[member.uid] ?? 0)} $currency',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.secondaryDark.withValues(alpha: 0.7),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            color: AppTheme.background,
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving || !isValid ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.textLight,
                  disabledBackgroundColor: AppTheme.secondaryDark.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: AppTheme.textLight)
                    : Text(
                        isValid 
                            ? 'Save' 
                            : _splitMode == 'Percentage'
                                ? 'Total must be 100% (${_formatAmount(_getTotalPercentage())}%)'
                                : 'Total must be ${_formatAmount(widget.amount)} $currency',
                        style: const TextStyle(fontSize: 14),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
