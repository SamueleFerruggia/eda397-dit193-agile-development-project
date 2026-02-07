import 'package:flutter/material.dart';
import 'package:simpleexpense/theme/app_theme.dart';

class GroupDetailScreen extends StatelessWidget {
  final Map<String, dynamic> group;

  const GroupDetailScreen({super.key, required this.group});

  String get _groupName => group['groupName'] as String? ?? 'Group Name';
  String get _currency => group['currency'] as String? ?? 'SEK';
  String get _inviteCode => group['inviteCode'] as String? ?? '------';

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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.white),
            onPressed: () => Navigator.of(context).pop(),
          ),

          const Spacer(),
          Column(
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
              Text(
                _inviteCode,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupInfo(BuildContext context) {
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
                _groupName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGray,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '0 $_currency',
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
  }
}
