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
  String? _infoMessage;
  double _amount = 0.0;
  String? _expenseId;

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settle Up'),
      ),
      body: FutureBuilder<List<GroupMember>>(
        future: FirestoreService().getGroupMembers(widget.groupId),
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
          final selectedMember = members.firstWhere(
            (m) => m.uid == _selectedUserId,
            orElse: () => members.first,
          );
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
                  onChanged: (value) {
                    setState(() {
                      _selectedUserId = value;
                      // For demo, just set amount and expenseId to dummy values
                      _amount = 10.0;
                      _expenseId = '';
                    });
                  },
                ),
                if (_selectedUserId != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'You will pay ${selectedMember.name} ${_amount.toStringAsFixed(2)} SEK.',
                    style: const TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _selectedUserId == null || _isSubmitting
                      ? null
                      : _onSettlePressed,
                  icon: const Icon(Icons.handshake),
                  label: const Text('Settle'),
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
    // For demo, just use dummy amount and expenseId
    double amount = _amount > 0 ? _amount : 1.0;
    String expenseId = _expenseId ?? '';
    await FirestoreService().createSettleRequest(
      groupId: widget.groupId,
      fromUserId: currentUserId!,
      toUserId: _selectedUserId!,
      amount: amount,
      expenseId: expenseId,
    );
    setState(() {
      _isSubmitting = false;
      _infoMessage = 'Settle request sent!';
    });
  }
}
