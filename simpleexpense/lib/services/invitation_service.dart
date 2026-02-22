import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import 'firestore_service.dart';

class InvitationService {
  final FirestoreService _firestoreService = FirestoreService();

  /// Send an invitation to join a group
  Future<String> sendInvitation({
    required String groupId,
    required String groupName,
    required String invitedBy,
    required String invitedByName,
    required String inviteCode,
    String? invitedEmail,
    int expiryDays = 7,
  }) async {
    try {
      final invitationId = await _firestoreService.createInvitation(
        groupId: groupId,
        groupName: groupName,
        invitedBy: invitedBy,
        invitedByName: invitedByName,
        inviteCode: inviteCode,
        invitedEmail: invitedEmail,
        expiryDays: expiryDays,
      );

      return invitationId;
    } catch (e) {
      throw Exception('Failed to send invitation: $e');
    }
  }

  /// Share invitation via system share dialog
  Future<void> shareInvitation({
    required String groupName,
    required String inviteCode,
    required BuildContext context,
  }) async {
    final message = '''
You're invited to join "$groupName" on SimplExpense!

Use this invite code to join: $inviteCode

1. Open SimplExpense app
2. Tap "Join Group"
3. Enter the code: $inviteCode

The invite code expires in 7 days.
''';

    try {
      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        message,
        subject: 'Join $groupName on SimplExpense',
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      throw Exception('Failed to share invitation: $e');
    }
  }

  /// Get all invitations for a group
  Future<List<GroupInvitation>> getGroupInvitations(String groupId) async {
    return await _firestoreService.getGroupInvitations(groupId);
  }

  /// Stream invitations for a group
  Stream<List<GroupInvitation>> streamGroupInvitations(String groupId) {
    return _firestoreService.streamGroupInvitations(groupId);
  }

  /// Get pending invitations for a user's email
  Future<List<GroupInvitation>> getPendingInvitations(String email) async {
    return await _firestoreService.getPendingInvitationsForEmail(email);
  }

  /// Accept an invitation
  Future<void> acceptInvitation({
    required String invitationId,
    required String userId,
  }) async {
    try {
      await _firestoreService.acceptInvitation(
        invitationId: invitationId,
        userId: userId,
      );
    } catch (e) {
      throw Exception('Failed to accept invitation: $e');
    }
  }

  /// Decline an invitation
  Future<void> declineInvitation(String invitationId) async {
    try {
      await _firestoreService.declineInvitation(invitationId);
    } catch (e) {
      throw Exception('Failed to decline invitation: $e');
    }
  }

  /// Revoke an invitation (admin only)
  Future<void> revokeInvitation(String invitationId) async {
    try {
      await _firestoreService.revokeInvitation(invitationId);
    } catch (e) {
      throw Exception('Failed to revoke invitation: $e');
    }
  }

  /// Delete an invitation
  Future<void> deleteInvitation(String invitationId) async {
    try {
      await _firestoreService.deleteInvitation(invitationId);
    } catch (e) {
      throw Exception('Failed to delete invitation: $e');
    }
  }

  /// Validate and get invitation by code
  Future<GroupInvitation?> validateInviteCode(String inviteCode) async {
    try {
      return await _firestoreService.getInvitationByCode(inviteCode);
    } catch (e) {
      throw Exception('Failed to validate invite code: $e');
    }
  }

  /// Check if user has pending invitations
  Future<int> getPendingInvitationCount(String email) async {
    return await _firestoreService.getPendingInvitationCount(email);
  }

  /// Generate shareable invitation link (for future implementation)
  String generateInvitationLink({
    required String inviteCode,
    required String groupName,
  }) {
    // This would be a deep link in production
    // For now, return a formatted string
    return 'simplexpense://join?code=$inviteCode&group=${Uri.encodeComponent(groupName)}';
  }

  /// Copy invite code to clipboard
  Future<void> copyInviteCodeToClipboard({
    required String inviteCode,
    required BuildContext context,
  }) async {
    try {
      // Note: This requires flutter/services.dart import in the calling widget
      // We'll handle the actual clipboard copy in the UI layer
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite code $inviteCode copied to clipboard!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      throw Exception('Failed to copy to clipboard: $e');
    }
  }

  /// Get invitation statistics for a group
  Future<Map<String, int>> getInvitationStats(String groupId) async {
    try {
      final invitations = await getGroupInvitations(groupId);
      
      return {
        'total': invitations.length,
        'pending': invitations.where((inv) => inv.status == InvitationStatus.pending && !inv.isExpired).length,
        'accepted': invitations.where((inv) => inv.status == InvitationStatus.accepted).length,
        'declined': invitations.where((inv) => inv.status == InvitationStatus.declined).length,
        'expired': invitations.where((inv) => inv.isExpired || inv.status == InvitationStatus.expired).length,
        'revoked': invitations.where((inv) => inv.status == InvitationStatus.revoked).length,
      };
    } catch (e) {
      return {
        'total': 0,
        'pending': 0,
        'accepted': 0,
        'declined': 0,
        'expired': 0,
        'revoked': 0,
      };
    }
  }
}