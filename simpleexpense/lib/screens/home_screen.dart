import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/auth_provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/screens/group_dashboard.dart';
import 'package:simpleexpense/screens/login_screen.dart';
import 'package:simpleexpense/screens/widgets/expense_widgets.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'create_group_step1.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().currentUserId;
    context.read<GroupsProvider>().startListening(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: const Text(
          'Simple Expense',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.white,
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await authProvider.logout();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ],
        elevation: 0,
      ),
      body: Consumer<GroupsProvider>(
        builder: (context, groupsProvider, _) {
          return groupsProvider.hasGroups
              ? _buildGroupsView(context)
              : _buildEmptyView(context);
        },
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Column(
          children: [
            // Account Header
            Container(
              color: Colors.grey[300],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    authProvider.currentUserName ?? 'Account Name',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),
            // Empty State
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CreateGroupStep1()),
                      );
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create a group',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupsView(BuildContext context) {
    return Column(
      children: [
        // Account Header with Balance
        Container(
          color: AppTheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, _) => Text(
                          authProvider.currentUserName ?? 'Account Name',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamilyDisplay,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '0 SEK | 0 SEK', // We will fix this global total later
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamilyDisplay,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildGroupsList(context),
        // Bottom Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: DropdownButton<String>(
                    value: 'Group',
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    dropdownColor: AppTheme.primary,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamilyDisplay,
                      color: AppTheme.textLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.textLight,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Group',
                        child: Text(
                          'Sort by Group',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamilyDisplay,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'People',
                        child: Text(
                          'Sort by People',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamilyDisplay,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {},
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => CreateGroupStep1()));
                },
                child: Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 24),
                      const SizedBox(height: 2),
                      const Text(
                        'Group',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsList(BuildContext context) {
    return Consumer<GroupsProvider>(
      builder: (context, groupsProvider, _) {
        final groups = groupsProvider.groups;
        return Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(0),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              // UPDATED: Using Model properties instead of Map keys
              final name = group.name;
              final currency = group.currency;
              final groupId = group.id;

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GroupDashboardScreen(groupId: groupId),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 64,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GroupBalanceStatusWidget(
                                  groupId: groupId,
                                  currency: currency,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
