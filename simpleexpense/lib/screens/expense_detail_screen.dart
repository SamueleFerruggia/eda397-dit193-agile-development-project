import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/services/firestore_service.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'package:simpleexpense/screens/widgets/expense_widgets.dart';
import '../models/models.dart';
import 'package:simpleexpense/services/expense_pdf_export.dart';
import 'package:simpleexpense/services/expense_csv_export.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final String description;
  final double amount;
  final String payerId;
  final Map<String, double> splitAmounts; // Map of userId -> amount
  final String splitType;
  final String? payerName;

  const ExpenseDetailScreen({
    super.key,
    required this.description,
    required this.amount,
    required this.payerId,
    required this.splitAmounts,
    this.splitType = '',
    this.payerName,
  });

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  void _showExportChoice(BuildContext context, GroupsProvider groupsProvider) {
    final currency = groupsProvider.currentCurrency ?? 'SEK';
    final groupName = groupsProvider.currentGroupName;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Text('Export expense detail'),
        content: const Text('Choose export format'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await exportExpenseDetailToPdf(
                description: widget.description,
                amount: widget.amount,
                currency: currency,
                payerId: widget.payerId,
                splitAmounts: widget.splitAmounts,
                payerName: widget.payerName,
                groupName: groupName,
              );
            },
            icon: const Icon(Icons.picture_as_pdf, size: 20),
            label: const Text('PDF'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await exportExpenseDetailToCsv(
                context: context,
                description: widget.description,
                amount: widget.amount,
                currency: currency,
                payerId: widget.payerId,
                splitAmounts: widget.splitAmounts,
                payerName: widget.payerName,
              );
            },
            icon: const Icon(Icons.table_chart, size: 20),
            label: const Text('CSV'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(
    BuildContext context,
    GroupsProvider groupsProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textLight),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.download,
              color: AppTheme.textLight,
              size: 24,
            ),
            onPressed: () => _showExportChoice(context, groupsProvider),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupsProvider>(
      builder: (context, groupsProvider, _) {
        final currency = groupsProvider.currentCurrency ?? 'SEK';
        final currentUser = FirebaseAuth.instance.currentUser;
        final groupId = groupsProvider.currentGroupId;

        return Scaffold(
          backgroundColor: AppTheme.primary,
          body: SafeArea(
            child: Column(
              children: [
                _buildDetailHeader(context, groupsProvider),
                const GroupInfoWidget(),
                // Main content
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(color: AppTheme.textLight),
                    child: FutureBuilder<List<GroupMember>>(
                      future: groupId != null
                          ? FirestoreService().getGroupMembers(groupId)
                          : Future.value([]),
                      builder: (context, memberSnapshot) {
                        // Build a uid -> name map
                        final Map<String, String> nameMap = {};
                        if (memberSnapshot.hasData) {
                          for (final m in memberSnapshot.data!) {
                            nameMap[m.uid] = m.name;
                          }
                        }

                        String displayName(String uid) {
                          if (uid == currentUser?.uid) return 'You';
                          return nameMap[uid] ?? 'Unknown';
                        }

                        final payerDisplay = displayName(widget.payerId);
                        final splitType = widget.splitType;

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),

                              // Expense item
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    left: BorderSide(
                                      color: Colors.grey[400]!,
                                      width: 8,
                                    ),
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(4),
                                    bottomRight: Radius.circular(4),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      offset: const Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.description,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    Text(
                                      '${widget.amount.toStringAsFixed(2)} $currency',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Info section
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                child: Text(
                                  'Total amount: ${widget.amount.toStringAsFixed(2)} $currency\n'
                                  'Paid by: $payerDisplay\n'
                                  'Split: $splitType',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textDark,
                                    height: 1.6,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Members section
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: widget.splitAmounts.length,
                                      itemBuilder: (context, index) {
                                        final entries = widget
                                            .splitAmounts
                                            .entries
                                            .toList();
                                        final userId = entries[index].key;
                                        final amount = entries[index].value;

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade300,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  displayName(userId),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF333333),
                                                  ),
                                                ),
                                                Text(
                                                  '${amount.toStringAsFixed(2)} $currency',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.textDark,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Buttons
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Back',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),
                            ],
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
      },
    );
  }
}
