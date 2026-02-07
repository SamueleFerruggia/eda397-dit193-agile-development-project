import 'package:flutter/material.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'create_group_step3.dart';

class CreateGroupStep2 extends StatefulWidget {
  final String groupName;
  const CreateGroupStep2({super.key, required this.groupName});

  @override
  State<CreateGroupStep2> createState() => _CreateGroupStep2State();
}

final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

class _CreateGroupStep2State extends State<CreateGroupStep2> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final List<String> _members = [];

  void _addMember() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _members.add(email);
      _emailController.clear();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Simple Expense',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: AppTheme.lightGray,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.groupName.isEmpty
                          ? 'Group Name'
                          : widget.groupName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Add friends to your group',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Add friends by email...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return null;
                        if (!_emailRegex.hasMatch(email))
                          return 'Enter a valid email';
                        if (_members.contains(email)) return 'Already added';
                        return null;
                      },
                      onFieldSubmitted: (_) => _addMember(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addMember,
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        label: const Text('Add email'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _members
                          .map((m) => Chip(label: Text(m)))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.middleGray),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: const [
                          Text(
                            'Share Invite Code',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'XXXXXX',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkGray,
                  ),
                  child: const Text('Next', style: TextStyle(fontSize: 16)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateGroupStep3(
                          groupName: widget.groupName,
                          invitedMembers: _members,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
