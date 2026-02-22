import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simpleexpense/providers/auth_provider.dart';
import 'package:simpleexpense/providers/groups_provider.dart';
import 'package:simpleexpense/screens/group_dashboard.dart';
import 'package:simpleexpense/screens/login_screen.dart';
import 'package:simpleexpense/screens/widgets/expense_widgets.dart';
import 'package:simpleexpense/theme/app_theme.dart';
import 'create_group_step1.dart';
import 'join_group_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:simpleexpense/services/balance_service.dart';
import 'package:simpleexpense/services/firestore_service.dart';
import 'package:simpleexpense/models/models.dart';

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
          'Home',
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
            // Header with Account Name and Groups
            Container(
              color: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${authProvider.currentUserName ?? 'Account Name'}'s",
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamilyDisplay,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Groups',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamilyDisplay,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Empty State Card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      const Text(
                        'Create a group\nwith friends!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamilyDisplay,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 48),
                      Icon(
                        Icons.groups,
                        size: 180,
                        color: AppTheme.primary,
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CreateGroupStep1(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Create a New Group',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamilyDisplay,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const JoinGroupScreen(),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppTheme.primary,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Have a code?',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamilyDisplay,
                                        fontSize: 14,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    Text(
                                      'Join a Group',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamilyDisplay,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
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
          color: AppTheme.background,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                      fontSize: 18,
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
                            fontSize: 18,
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
                            fontSize: 18,
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
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const JoinGroupScreen()),
                  );
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
                      const Icon(Icons.group_add, color: Colors.white, size: 24),
                      const SizedBox(height: 2),
                      const Text(
                        'Join',
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
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => CreateGroupStep1()));
                },
                child: Container(
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(34),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 28),
                      const SizedBox(height: 2),
                      const Text(
                        'Group',
                        style: TextStyle(
                          fontSize: 12,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'All Groups',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamilyDisplay,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(0),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
              final group = groups[index];
              // UPDATED: Using Model properties instead of Map keys
              final name = group.name;
              final currency = group.currency;
              final groupId = group.id;

              return Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  final currentUserId = authProvider.currentUserId;
                  
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('groups')
                        .doc(groupId)
                        .collection('expenses')
                        .snapshots(),
                    builder: (context, expenseSnapshot) {
                      Color cardColor = Colors.grey.shade300;
                      
                      if (expenseSnapshot.hasData && currentUserId != null) {
                        final expenses = expenseSnapshot.data!.docs
                            .map((doc) => Expense.fromFirestore(doc))
                            .toList();
                        
                        final firestoreService = FirestoreService();
                        final balanceService = BalanceService();
                        
                        // We need to use FutureBuilder for members
                        return FutureBuilder<List<GroupMember>>(
                          future: firestoreService.getGroupMembers(groupId),
                          builder: (context, memberSnapshot) {
                            if (memberSnapshot.hasData) {
                              final members = memberSnapshot.data!;
                              final balances = balanceService.calculateNetBalances(expenses, members);
                              final myBalance = balances[currentUserId] ?? 0.0;
                              
                              if (myBalance > 0.01) {
                                cardColor = Colors.green.shade400;
                              } else if (myBalance < -0.01) {
                                cardColor = Colors.red.shade400;
                              }
                            }
                            
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
                                          color: cardColor,
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
                                                groupName: name,
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
                        );
                      }
                      
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
                                    color: cardColor,
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
                                          groupName: name,
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
                  );
                },
              );
            },
          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
