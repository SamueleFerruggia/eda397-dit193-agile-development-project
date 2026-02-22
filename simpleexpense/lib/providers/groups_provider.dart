import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../services/invitation_service.dart';
import '../models/models.dart';

class GroupsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final InvitationService _invitationService = InvitationService();

  // Changed from List<Map> to List<Group>
  List<Group> _groups = [];
  List<Group> get groups => List.unmodifiable(_groups);

  bool get hasGroups => _groups.isNotEmpty;

  // Store for group balances and members
  final Map<String, double> _groupBalances = {};
  final Map<String, int> _groupMembers = {};

  StreamSubscription<List<Group>>? _subscription;
  String? _currentUid;
  String? get currentUid => _currentUid;

  String? _selectedGroupId;

  /// Get the currently selected group, or the first group if none selected
  Group? get selectedGroup {
    if (_groups.isEmpty) return null;
    if (_selectedGroupId != null) {
      try {
        return _groups.firstWhere((g) => g.id == _selectedGroupId);
      } catch (e) {
        return _groups.first;
      }
    }
    return _groups.first;
  }

  // Getters now use Model properties instead of Map keys ['key']
  String? get currentInviteCode => selectedGroup?.inviteCode;
  String? get currentGroupId => selectedGroup?.id;
  String? get currentGroupName => selectedGroup?.name;
  String? get currentCurrency => selectedGroup?.currency;

  /// Get total balance for the currently selected group
  double get currentGroupTotalBalance {
    final groupId = currentGroupId;
    return groupId != null ? _groupBalances[groupId] ?? 0 : 0;
  }

  /// Get total members for the currently selected group
  int get currentGroupMembers {
    final groupId = currentGroupId;
    return groupId != null ? _groupMembers[groupId] ?? 0 : 0;
  }

  /// Get total balance for a specific group by ID
  double getGroupBalance(String groupId) {
    return _groupBalances[groupId] ?? 0;
  }

  /// Get total members for a specific group by ID
  int getGroupMemberCount(String groupId) {
    return _groupMembers[groupId] ?? 0;
  }

  /// Select a specific group by ID
  void selectGroup(String groupId) {
    _selectedGroupId = groupId;
    notifyListeners();
  }

  /// Start listening to groups for the given user.
  void startListening(String? uid) {
    if (uid == _currentUid) return;
    _currentUid = uid;

    _subscription?.cancel();
    _subscription = null;

    if (uid == null || uid.isEmpty) {
      _groups = [];
      _groupBalances.clear();
      _groupMembers.clear();
      notifyListeners();
      return;
    }

    // Now listening to Stream<List<Group>>
    _subscription = _firestoreService.streamUserGroups(uid).listen((list) {
      _groups = list;

      // Subscribe to balance and members streams for each group
      for (var group in _groups) {
        final groupId = group.id;
        
        // Listen to balance updates
        _firestoreService.streamGroupTotalBalance(groupId).listen((balance) {
          _groupBalances[groupId] = balance;
          notifyListeners();
        });

        // Listen to member count updates
        _firestoreService.streamGroupMembersCount(groupId).listen((count) {
          _groupMembers[groupId] = count;
          notifyListeners();
        });
      }

      notifyListeners();
    });
  }

  /// Join a group using invite code
  Future<void> joinGroupByCode({
    required String uid,
    required String inviteCode,
  }) async {
    await _firestoreService.joinGroupByCode(uid: uid, inviteCode: inviteCode);
    // The stream will automatically update the list
  }

  // --- INVITATION METHODS ---

  /// Send an invitation to join the current group
  Future<String> sendInvitation({
    required String invitedByName,
    String? invitedEmail,
    int expiryDays = 7,
  }) async {
    final group = selectedGroup;
    if (group == null) {
      throw Exception('No group selected');
    }

    if (_currentUid == null) {
      throw Exception('User not authenticated');
    }

    return await _invitationService.sendInvitation(
      groupId: group.id,
      groupName: group.name,
      invitedBy: _currentUid!,
      invitedByName: invitedByName,
      inviteCode: group.inviteCode,
      invitedEmail: invitedEmail,
      expiryDays: expiryDays,
    );
  }

  /// Get all invitations for the current group
  Future<List<GroupInvitation>> getGroupInvitations() async {
    final groupId = currentGroupId;
    if (groupId == null) {
      return [];
    }
    return await _invitationService.getGroupInvitations(groupId);
  }

  /// Stream invitations for the current group
  Stream<List<GroupInvitation>> streamGroupInvitations() {
    final groupId = currentGroupId;
    if (groupId == null) {
      return Stream.value([]);
    }
    return _invitationService.streamGroupInvitations(groupId);
  }

  /// Get pending invitations for a user's email
  Future<List<GroupInvitation>> getPendingInvitations(String email) async {
    return await _invitationService.getPendingInvitations(email);
  }

  /// Accept an invitation
  Future<void> acceptInvitation({
    required String invitationId,
    required String userId,
  }) async {
    await _invitationService.acceptInvitation(
      invitationId: invitationId,
      userId: userId,
    );
  }

  /// Decline an invitation
  Future<void> declineInvitation(String invitationId) async {
    await _invitationService.declineInvitation(invitationId);
  }

  /// Revoke an invitation (admin only)
  Future<void> revokeInvitation(String invitationId) async {
    await _invitationService.revokeInvitation(invitationId);
  }

  /// Delete an invitation
  Future<void> deleteInvitation(String invitationId) async {
    await _invitationService.deleteInvitation(invitationId);
  }

  /// Get invitation statistics for current group
  Future<Map<String, int>> getInvitationStats() async {
    final groupId = currentGroupId;
    if (groupId == null) {
      return {
        'total': 0,
        'pending': 0,
        'accepted': 0,
        'declined': 0,
        'expired': 0,
        'revoked': 0,
      };
    }
    return await _invitationService.getInvitationStats(groupId);
  }

  void stopListening() {
    startListening(null);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}