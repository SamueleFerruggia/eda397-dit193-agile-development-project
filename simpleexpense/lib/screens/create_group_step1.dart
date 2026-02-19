import 'package:flutter/material.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'create_group_step2.dart';

class CreateGroupStep1 extends StatefulWidget {
  const CreateGroupStep1({super.key});

  @override
  State<CreateGroupStep1> createState() => _CreateGroupStep1State();
}

class _CreateGroupStep1State extends State<CreateGroupStep1> {
  final _formKey = GlobalKey<FormState>();
  String _savedName = '';

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
        backgroundColor: AppTheme.background,
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
                    const SizedBox(height: 8),
                    const Text(
                      'Creating a new group',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      decoration: const InputDecoration(
                        hintText: 'Enter a group name...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      maxLength: 50,
                      validator: (value) {
                        final name = value?.trim() ?? '';
                        if (name.isEmpty) return 'Group name is required';
                        return null;
                      },
                      onSaved: (value) {
                        _savedName = value?.trim() ?? '';
                      },
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
                    backgroundColor: AppTheme.primary,
                  ),
                  child: const Text('Next', style: TextStyle(fontSize: 16)),
                  onPressed: () {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    _formKey.currentState?.save();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateGroupStep2(groupName: _savedName),
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
