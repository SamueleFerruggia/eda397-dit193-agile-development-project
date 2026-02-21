import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import '../services/firestore_service.dart';

class CreateGroupStep3 extends StatefulWidget {
  final String groupName;
  final List<String> invitedMembers;
  final String inviteCode;

  const CreateGroupStep3({
    super.key,
    required this.groupName,
    required this.invitedMembers,
    required this.inviteCode,
  });

  @override
  State<CreateGroupStep3> createState() => _CreateGroupStep3State();
}

class _CreateGroupStep3State extends State<CreateGroupStep3> {
  String _currency = 'SEK';
  bool _isCreating = false; // State to manage the creation process
  final FirestoreService _firestoreService = FirestoreService();

  // Handles the save to Firebase
  void _handleCreateGroup() async {
    setState(() => _isCreating = true);

    try {
      // 1. Obtain the current agent (it will be the admin)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }

      // 2. Call the database to create the group with all the collected data
      await _firestoreService.createGroup(
        groupName: widget.groupName,
        creatorId: user.uid,
        invitedEmails: widget.invitedMembers,
        currency: _currency,
        inviteCode: widget.inviteCode,
      );

      if (!mounted) return;

      // 3. Success: Back to home screen
      Navigator.of(context).popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      // Error management
      String errorMessage = 'Error creating group';

      // Handle network errors specifically
      if (e.toString().contains('Network') ||
          e.toString().contains('connection') ||
          e.toString().contains('Connection refused')) {
        errorMessage = 'Creation failed, please try again later';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
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
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          // Disable the back button during group creation to prevent navigation issues
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Choose the currency',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.secondaryDark),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: DropdownButton<String>(
                        value: _currency,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'SEK', child: Text('SEK')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                        ],
                        // Disable the change value when creating the group
                        onChanged: _isCreating
                            ? null
                            : (v) {
                                if (v != null) setState(() => _currency = v);
                              },
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Applies to all expenses',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                // Disable the button during saving
                onPressed: _isCreating ? null : _handleCreateGroup,
                child: _isCreating
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Done!', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
