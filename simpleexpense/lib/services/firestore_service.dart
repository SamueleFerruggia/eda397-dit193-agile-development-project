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
      'invitedEmails': invitedEmails, // Save the list of invited emails for later processing
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }
}