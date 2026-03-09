import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:simpleexpense/models/models.dart';
import 'package:simpleexpense/services/firestore_service.dart';
import 'package:simpleexpense/theme/app_theme.dart';

/// Screen displaying archived (settled) expenses for a group.
class ArchivedSettlementsScreen extends StatelessWidget {
  final String groupId;

  const ArchivedSettlementsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.textLight,
        title: const Text(
          'Archived Settlements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: FutureBuilder<List<GroupMember>>(
        future: firestoreService.getGroupMembers(groupId),
        builder: (context, memberSnapshot) {
          // Build a uid→name map once members are loaded
          final memberNames = <String, String>{};
          if (memberSnapshot.hasData) {
            for (final m in memberSnapshot.data!) {
              memberNames[m.uid] = m.name;
            }
          }

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: firestoreService.streamArchivedExpenses(groupId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  memberSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading archived settlements',
                    style: TextStyle(color: AppTheme.error),
                  ),
                );
              }

              final archives = snapshot.data ?? [];

              if (archives.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No archived settlements yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.secondaryDark,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: archives.length,
                itemBuilder: (context, index) {
                  return _buildArchiveCard(
                    context,
                    archives[index],
                    memberNames,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildArchiveCard(
    BuildContext context,
    Map<String, dynamic> archive,
    Map<String, String> memberNames,
  ) {
    final amount = (archive['amount'] as num?)?.toDouble() ?? 0.0;
    final archivedAt = (archive['archivedAt'] as Timestamp?)?.toDate();
    final involvedUsers = List<String>.from(
      archive['involvedUsers'] as List? ?? [],
    );
    final isSettlementRecord = archive['type'] == 'settlement';

    // Format the archived date
    String dateStr = 'Unknown date';
    if (archivedAt != null) {
      dateStr =
          '${archivedAt.year}-${archivedAt.month.toString().padLeft(2, '0')}-${archivedAt.day.toString().padLeft(2, '0')} '
          '${archivedAt.hour.toString().padLeft(2, '0')}:${archivedAt.minute.toString().padLeft(2, '0')}';
    }

    if (isSettlementRecord) {
      // New format: settlement record
      final debtorId = archive['debtorId'] as String? ?? '';
      final creditorId = archive['creditorId'] as String? ?? '';
      final debtorName = memberNames[debtorId] ?? 'Unknown';
      final creditorName = memberNames[creditorId] ?? 'Unknown';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.handshake, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Debt Settled',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                Text(
                  amount.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$debtorName paid $creditorName',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.secondaryDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Settled: $dateStr',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    // Legacy format: archived expense copy
    final description = archive['description'] as String? ?? 'Expense';
    final payerName = archive['payerName'] as String? ?? 'Unknown';

    int splitCount = 0;
    if (archive['splitAmounts'] != null) {
      splitCount = (archive['splitAmounts'] as Map).length;
    } else if (archive['splitWith'] != null) {
      splitCount = (archive['splitWith'] as List).length;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.archive, color: AppTheme.secondaryDark, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  description,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              Text(
                amount.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Paid by $payerName · Split $splitCount ways',
            style: TextStyle(fontSize: 13, color: AppTheme.secondaryDark),
          ),
          const SizedBox(height: 4),
          Text(
            'Settled between: ${involvedUsers.join(', ')}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            'Archived: $dateStr',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
