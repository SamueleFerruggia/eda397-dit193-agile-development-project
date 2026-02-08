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
  Future<void> createGroup({
    required String groupName,
    required String creatorId,
    required List<String> invitedEmails, // List of invited emails
    required String currency,
  }) async {
    // Generate a unique invite code for the group (6 characters alphanumeric)
    String inviteCode = _generateInviteCode();

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
    // Add the document to the 'expenses' sub-collection of the group
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .add({
      'description': description,
      'amount': amount,
      'payerId': payerId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
