import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
      debugPrint('Error fetching group members: $e');
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

  // --- INVITATIONS ---

  /// Create a new invitation for a group
  Future<String> createInvitation({
    required String groupId,
    required String groupName,
    required String invitedBy,
    required String invitedByName,
    required String inviteCode,
    String? invitedEmail,
    int? expiryDays,
  }) async {
    final invitationRef = _db.collection('invitations').doc();
    
    final expiresAt = expiryDays != null
        ? DateTime.now().add(Duration(days: expiryDays))
        : null;

    await invitationRef.set({
      'groupId': groupId,
      'groupName': groupName,
      'invitedBy': invitedBy,
      'invitedByName': invitedByName,
      'invitedEmail': invitedEmail,
      'inviteCode': inviteCode,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
    });

    return invitationRef.id;
  }

  /// Get all invitations for a specific group
  Future<List<GroupInvitation>> getGroupInvitations(String groupId) async {
    try {
      final snapshot = await _db
          .collection('invitations')
          .where('groupId', isEqualTo: groupId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => GroupInvitation.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching group invitations: $e');
      return [];
    }
  }

  /// Stream invitations for a specific group
  Stream<List<GroupInvitation>> streamGroupInvitations(String groupId) {
    return _db
        .collection('invitations')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
          final invitations = snapshot.docs
              .map((doc) => GroupInvitation.fromFirestore(doc))
              .toList();
          
          // Sort in memory instead of using Firestore orderBy
          // This avoids the need for a composite index
          invitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          return invitations;
        });
  }

  /// Get pending invitations for a specific email
  Future<List<GroupInvitation>> getPendingInvitationsForEmail(String email) async {
    try {
      final snapshot = await _db
          .collection('invitations')
          .where('invitedEmail', isEqualTo: email.toLowerCase())
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs
          .map((doc) => GroupInvitation.fromFirestore(doc))
          .where((inv) => !inv.isExpired)
          .toList();
    } catch (e) {
      debugPrint('Error fetching pending invitations: $e');
      return [];
    }
  }

  /// Accept an invitation
  Future<void> acceptInvitation({
    required String invitationId,
    required String userId,
  }) async {
    final invitationDoc = await _db.collection('invitations').doc(invitationId).get();
    
    if (!invitationDoc.exists) {
      throw Exception('Invitation not found');
    }

    final invitation = GroupInvitation.fromFirestore(invitationDoc);
    
    if (invitation.status != InvitationStatus.pending) {
      throw Exception('Invitation is no longer valid');
    }

    if (invitation.isExpired) {
      throw Exception('Invitation has expired');
    }

    // Add user to group
    await _db.collection('groups').doc(invitation.groupId).update({
      'members': FieldValue.arrayUnion([userId]),
    });

    // Update invitation status
    await _db.collection('invitations').doc(invitationId).update({
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Decline an invitation
  Future<void> declineInvitation(String invitationId) async {
    await _db.collection('invitations').doc(invitationId).update({
      'status': 'declined',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Revoke an invitation (admin only)
  Future<void> revokeInvitation(String invitationId) async {
    await _db.collection('invitations').doc(invitationId).update({
      'status': 'revoked',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete an invitation
  Future<void> deleteInvitation(String invitationId) async {
    await _db.collection('invitations').doc(invitationId).delete();
  }

  /// Get invitation by invite code
  Future<GroupInvitation?> getInvitationByCode(String inviteCode) async {
    try {
      final snapshot = await _db
          .collection('invitations')
          .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final invitation = GroupInvitation.fromFirestore(snapshot.docs.first);
      
      if (invitation.isExpired) {
        // Mark as expired
        await _db.collection('invitations').doc(invitation.id).update({
          'status': 'expired',
        });
        return null;
      }

      return invitation;
    } catch (e) {
      debugPrint('Error fetching invitation by code: $e');
      return null;
    }
  }

  /// Check if user has pending invitations
  Future<int> getPendingInvitationCount(String email) async {
    try {
      final snapshot = await _db
          .collection('invitations')
          .where('invitedEmail', isEqualTo: email.toLowerCase())
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs
          .map((doc) => GroupInvitation.fromFirestore(doc))
          .where((inv) => !inv.isExpired)
          .length;
    } catch (e) {
      debugPrint('Error counting pending invitations: $e');
      return 0;
    }
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