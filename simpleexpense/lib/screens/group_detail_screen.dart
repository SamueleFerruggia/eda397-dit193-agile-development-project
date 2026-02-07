import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'package:simpleexpense/screens/add_expense_screen.dart';
import '../providers/groups_provider.dart';
import 'package:flutter/services.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupsProvider>().selectGroup(widget.groupId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkGray,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildGroupInfo(context),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(color: AppTheme.white),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddExpenseStep1(),
                      ),
                    );
                  },
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.darkGray,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: AppTheme.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Add Expense',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.darkGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Consumer<GroupsProvider>(
        builder: (context, groupsProvider, child) {
          final inviteCode = groupsProvider.currentInviteCode ?? '------';

          return Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (inviteCode != '------') {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invite code copied to clipboard'),
                        duration: Duration(milliseconds: 1500),
                      ),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Share Invite Code',
                      style: TextStyle(
                        color: AppTheme.middleGray,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          inviteCode,
                          style: const TextStyle(
                            color: AppTheme.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.content_copy,
                          color: AppTheme.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGroupInfo(BuildContext context) {
    return Consumer<GroupsProvider>(
      builder: (context, groupsProvider, child) {
        return Container(
          color: Colors.grey[300],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppTheme.lightGray),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupsProvider.currentGroupName ?? 'Group Name',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '0 ${groupsProvider.currentCurrency ?? 'SEK'}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
