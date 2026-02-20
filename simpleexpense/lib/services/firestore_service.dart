import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- USERS ---

  Future<void> saveUser(String uid, String email, String name) async {
    await _db.collection('users').doc(uid).set({
      'userId': uid,
      'email': email,
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --- GROUPS ---

  Future<String> createGroup({
    required String groupName,
    required String creatorId,
    required List<String> invitedEmails,
    required String currency,
    required String inviteCode,
  }) async {
    DocumentReference groupRef = _db.collection('groups').doc();

    await groupRef.set({
      'groupId': groupRef.id,
      'groupName': groupName,
      'adminId': creatorId,
      'inviteCode': inviteCode,
      'currency': currency,
      'members': [creatorId],
      'invitedEmails': invitedEmails,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return groupRef.id;
  }

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

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    try {
      final groupDoc = await _db.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return [];

      final group = Group.fromFirestore(groupDoc);
      final memberIds = group.memberIds;

      if (memberIds.isEmpty) return [];

      List<GroupMember> members = [];

      // Fetch in chunks of 10 (Firestore limit for 'whereIn')
      for (var i = 0; i < memberIds.length; i += 10) {
        final end = (i + 10 < memberIds.length) ? i + 10 : memberIds.length;
        final chunk = memberIds.sublist(i, end);

        final usersSnapshot = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in usersSnapshot.docs) {
          final user = AppUser.fromFirestore(doc);
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
      throw Exception('Invalid invite code.');
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

  Future<void> addExpense({
    required String groupId,
    required String description,
    required double amount,
    required String payerId,
    required Map<String, double> splitAmounts, // Map of userId -> amount
  }) async {
    await _db.collection('groups').doc(groupId).collection('expenses').add({
      'description': description,
      'amount': amount,
      'payerId': payerId,
      'splitAmounts': splitAmounts,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateExpense({
    required String groupId,
    required String expenseId,
    required String description,
    required double amount,
    required String payerId,
    required Map<String, double> splitAmounts,
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
          'splitAmounts': splitAmounts,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

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

  Stream<int> streamGroupMembersCount(String groupId) {
    return _db.collection('groups').doc(groupId).snapshots().map((doc) {
      final members = doc['members'] as List? ?? [];
      return members.length;
    });
  }
}