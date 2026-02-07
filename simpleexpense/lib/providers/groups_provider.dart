import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';

class GroupsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> get groups => List.unmodifiable(_groups);

  bool get hasGroups => _groups.isNotEmpty;

  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  String? _currentUid;

  /// Start listening to groups for the given user. Call with null to stop and clear.
  /// No-op if already listening to the same uid.
  void startListening(String? uid) {
    if (uid == _currentUid) return;
    _currentUid = uid;

    _subscription?.cancel();
    _subscription = null;

    if (uid == null || uid.isEmpty) {
      _groups = [];
      notifyListeners();
      return;
    }

    _subscription = _firestoreService.streamUserGroups(uid).listen((list) {
      _groups = list;
      notifyListeners();
    });
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
