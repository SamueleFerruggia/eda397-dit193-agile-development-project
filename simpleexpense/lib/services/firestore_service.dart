import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- USERS ---

  // Save user data to Firestore after registration (based on the class diagram)
  Future<void> saveUser(String uid, String email, String name) async {
    await _db.collection('users').doc(uid).set({
      'userId': uid,
      'email': email,
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --- GROUPS ---

  // Create a new group
  Future<String> createGroup({
    required String groupName,
    required String creatorId,
    required List<String> invitedEmails, // List of invited emails
    required String currency,
    required String inviteCode, // Pre-generated invite code
  }) async {
    // Create a new document in the 'groups' collection with an auto-generated ID
    DocumentReference groupRef = _db.collection('groups').doc();

    await groupRef.set({
      'groupId': groupRef.id,
      'groupName': groupName,
      'adminId': creatorId,
      'inviteCode': inviteCode,
      'currency': currency,
      'members': [creatorId], // admin is the first member of the group
      'invitedEmails':
          invitedEmails, // Save the list of invited emails for later processing
      'createdAt': FieldValue.serverTimestamp(),
    });

    return groupRef.id; // Return the created group ID
  }

  /// Stream of groups where the user is a member. Returns empty list when uid is null/empty.
  Stream<List<Map<String, dynamic>>> streamUserGroups(String? uid) {
    if (uid == null || uid.isEmpty) {
      return Stream.value([]);
    }
    return _db
        .collection('groups')
        .where('members', arrayContains: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['groupId'] = doc.id;
            return data;
          }).toList(),
        );
  }

  /// Join a group using the invite code. Throws an exception if the code is invalid or user is already a member.
  Future<void> joinGroupByCode({
    required String uid,
    required String inviteCode,
  }) async {
    // Find the group with the matching invite code
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

    // Check if user is already a member
    if (members.contains(uid)) {
      throw Exception('You are already a member of this group.');
    }

    // Add user to the group's members list
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

  // Adds a new expense to the specified group
  Future<void> addExpense({
    required String groupId,
    required String description,
    required double amount,
    required String payerId,
  }) async {
    await _db.collection('groups').doc(groupId).collection('expenses').add({
      'description': description,
      'amount': amount,
      'payerId': payerId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Updates an existing expense (description, amount, payerId).
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

  /// Get total balance for a group (sum of all expenses)
  Future<double> getGroupTotalBalance(String groupId) async {
    try {
      final snapshot = await _db
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .get();

      double total = 0;
      for (var doc in snapshot.docs) {
        final amount = doc['amount'] as num? ?? 0;
        total += amount.toDouble();
      }
      return total;
    } catch (e) {
      return 0;
    }
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

  /// Get total members count for a group
  Future<int> getGroupMembersCount(String groupId) async {
    try {
      final doc = await _db.collection('groups').doc(groupId).get();
      final members = doc['members'] as List? ?? [];
      return members.length;
    } catch (e) {
      return 0;
    }
  }

  /// Stream of members for a group
  Stream<int> streamGroupMembersCount(String groupId) {
    return _db.collection('groups').doc(groupId).snapshots().map((doc) {
      final members = doc['members'] as List? ?? [];
      return members.length;
    });
  }
}
