import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/auth_provider.dart';
import 'package:simpleexpense/services/firestore_service.dart';
import '../models/models.dart';

/// Screen for settling up with another group member
class SettleScreen extends StatefulWidget {
  final String groupId;
  const SettleScreen({super.key, required this.groupId});

  @override
  State<SettleScreen> createState() => _SettleScreenState();
}

class _SettleScreenState extends State<SettleScreen> {
  String? _selectedUserId;
  bool _isSubmitting = false;
  bool _isLoadingDebt = false;
  String? _infoMessage;
  double _amount = 0.0;
  String? _debtorId;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settle Up'),
      ),
      body: FutureBuilder<List<GroupMember>>(
        future: _firestoreService.getGroupMembers(widget.groupId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final members = snapshot.data!
              .where((m) => m.uid != currentUserId)
              .toList();
          if (members.isEmpty) {
            return const Center(child: Text('No other members to settle with.'));
          }
          final selectedMember = _selectedUserId != null
              ? members.firstWhere(
                  (m) => m.uid == _selectedUserId,
                  orElse: () => members.first,
                )
              : null;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a person to settle with:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: _selectedUserId,
                  hint: const Text('Choose member'),
                  isExpanded: true,
                  items: members.map((member) {
                    return DropdownMenuItem(
                      value: member.uid,
                      child: Text(member.name),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    setState(() {
                      _selectedUserId = value;
                      _isLoadingDebt = true;
                      _amount = 0.0;
                      _debtorId = null;
                      _infoMessage = null;
                    });
                    if (value != null && currentUserId != null) {
                      final debt = await _firestoreService.getPairwiseDebt(
                        groupId: widget.groupId,
                        userA: currentUserId,
                        userB: value,
                      );
                      if (mounted) {
                        setState(() {
                          _amount = (debt['amount'] as num).toDouble();
                          _debtorId = debt['debtorId'] as String;
                          _isLoadingDebt = false;
                        });
                      }
                    }
                  },
                ),
                if (_isLoadingDebt) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ] else if (_selectedUserId != null && selectedMember != null) ...[
                  const SizedBox(height: 16),
                  if (_amount < 0.01)
                    Text(
                      'You and ${selectedMember.name} are already settled up!',
                      style: const TextStyle(fontSize: 16, color: Colors.green),
                    )
                  else if (_debtorId == currentUserId)
                    Text(
                      'You owe ${selectedMember.name} ${_amount.toStringAsFixed(2)} SEK.',
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    )
                  else
                    Text(
                      '${selectedMember.name} owes you ${_amount.toStringAsFixed(2)} SEK.',
                      style: const TextStyle(fontSize: 16, color: Colors.blue),
                    ),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _selectedUserId == null || _isSubmitting || _amount < 0.01
                      ? null
                      : _onSettlePressed,
                  icon: const Icon(Icons.handshake),
                  label: const Text('Send Settlement Request'),
                ),
                if (_infoMessage != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    _infoMessage!,
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _onSettlePressed() async {
    setState(() {
      _isSubmitting = true;
      _infoMessage = null;
    });
    final currentUserId = context.read<AuthProvider>().currentUserId;
    await _firestoreService.createSettleRequest(
      groupId: widget.groupId,
      fromUserId: currentUserId!,
      toUserId: _selectedUserId!,
      amount: _amount,
      expenseId: '',
    );
    setState(() {
      _isSubmitting = false;
      _infoMessage = 'Settle request sent!';
    });
  }
}
