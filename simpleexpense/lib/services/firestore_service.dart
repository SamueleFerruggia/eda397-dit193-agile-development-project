import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- USERS ---

  /// Save user data to Firestore after registration.
  Future<void> saveUser(String uid, String email, String name) async {
    // We can use the AppUser model here too if we want, but saving directly is fine for now
    await _db.collection('users').doc(uid).set({
      'userId': uid,
      'email': email,
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --- GROUPS ---

  /// Create a new group.
  Future<String> createGroup({
    required String groupName,
    required String creatorId,
    required List<String> invitedEmails,
    required String currency,
    required String inviteCode,
  }) async {
    DocumentReference groupRef = _db.collection('groups').doc();

    // Create the Group object (we use the model structure logic here)
    await groupRef.set({
      'groupId': groupRef.id,
      'groupName': groupName,
      'adminId': creatorId,
      'inviteCode': inviteCode,
      'currency': currency,
      'members': [creatorId], // Creator is the first member
      'invitedEmails': invitedEmails,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return groupRef.id;
  }

  /// Stream of groups where the user is a member.
  /// UPDATED: Now returns a List<Group> model instead of raw Maps.
  Stream<List<Group>> streamUserGroups(String? uid) {
    if (uid == null || uid.isEmpty) {
      return Stream.value([]);
    }
    return _db
        .collection('groups')
        .where('members', arrayContains: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Group.fromFirestore(doc))
              .toList(),
        );
  }

  /// Fetches the details of all members in a group (Names, Emails, Roles).
  /// This is needed to display "Mario" instead of "user_123".
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    try {
      // 1. Fetch the group document to get the member list and admin ID
      final groupDoc = await _db.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return [];

      final group = Group.fromFirestore(groupDoc);
      final memberIds = group.memberIds;

      if (memberIds.isEmpty) return [];

      List<GroupMember> members = [];

      // 2. Fetch user documents.
      // Firestore 'whereIn' is limited to 10 values per query.
      // We process the IDs in chunks of 10 to avoid errors with large groups.
      for (var i = 0; i < memberIds.length; i += 10) {
        final end = (i + 10 < memberIds.length) ? i + 10 : memberIds.length;
        final chunk = memberIds.sublist(i, end);

        final usersSnapshot = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in usersSnapshot.docs) {
          final user = AppUser.fromFirestore(doc);
          
          // Determine the role (Admin vs Member)
          final role = (user.uid == group.adminId) ? 'admin' : 'member';
          
          members.add(GroupMember.fromUser(user, role: role));
        }
      }

      return members;
    } catch (e) {
      print('Error fetching group members: $e');
      return [];
    }
  }

  /// Join a group using the invite code.
  Future<void> joinGroupByCode({
    required String uid,
    required String inviteCode,
  }) async {
    final querySnapshot = await _db
        .collection('groups')
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Invalid invite code. Please check and try again.');
    }

    final groupDoc = querySnapshot.docs.first;
    final groupId = groupDoc.id;
    final members = List<String>.from(groupDoc['members'] as List? ?? []);

    if (members.contains(uid)) {
      throw Exception('You are already a member of this group.');
    }

    await _db.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([uid]),
    });
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  // --- EXPENSES ---

  /// Adds a new expense to the specified group.
  Future<void> addExpense({
    required String groupId,
    required String description,
    required double amount,
    required String payerId,
  }) async {
    // We could use Expense(...).toJson() here, but passing primitives is fine too
    await _db.collection('groups').doc(groupId).collection('expenses').add({
      'description': description,
      'amount': amount,
      'payerId': payerId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Updates an existing expense.
  Future<void> updateExpense({
    required String groupId,
    required String expenseId,
    required String description,
    required double amount,
    required String payerId,
  }) async {
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .doc(expenseId)
        .update({
          'description': description,
          'amount': amount,
          'payerId': payerId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Stream of total balance for a group
  Stream<double> streamGroupTotalBalance(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .snapshots()
        .map((snapshot) {
          double total = 0;
          for (var doc in snapshot.docs) {
            final amount = doc['amount'] as num? ?? 0;
            total += amount.toDouble();
          }
          return total;
        });
  }

  /// Stream of members count for a group
  Stream<int> streamGroupMembersCount(String groupId) {
    return _db.collection('groups').doc(groupId).snapshots().map((doc) {
      final members = doc['members'] as List? ?? [];
      return members.length;
    });
  }
}