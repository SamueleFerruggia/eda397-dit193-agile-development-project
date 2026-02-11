import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../models/models.dart';

class GroupsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

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

  void stopListening() {
    startListening(null);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}