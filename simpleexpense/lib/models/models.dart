import 'package:cloud_firestore/cloud_firestore.dart';

// --- USER MODEL ---
/// Represents a user in the application (stored in the 'users' collection).
class AppUser {
  final String uid;
  final String email;
  final String name;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.createdAt,
  });

  /// Factory method to create an AppUser from a Firestore document.
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      // Safely convert Firestore Timestamp to Dart DateTime
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts the user object to a Map for saving to Firestore.
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// --- GROUP MODEL ---
/// Represents an expense group (stored in the 'groups' collection).
class Group {
  final String id;
  final String name;
  final String adminId; // The creator/admin UID
  final String inviteCode;
  final String currency;
  final List<String> memberIds; // List of User UIDs
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.adminId,
    required this.inviteCode,
    required this.currency,
    required this.memberIds,
    required this.createdAt,
  });

  /// Factory method to create a Group from a Firestore document.
  factory Group.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      // Note: The field in Firestore is 'groupName', mapped to 'name' here
      name: data['groupName'] ?? '', 
      adminId: data['adminId'] ?? '',
      inviteCode: data['inviteCode'] ?? '',
      currency: data['currency'] ?? 'SEK',
      // Safely convert the dynamic list to a List<String>
      memberIds: List<String>.from(data['members'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts the group object to a Map for saving to Firestore.
  Map<String, dynamic> toJson() {
    return {
      'groupName': name,
      'adminId': adminId,
      'inviteCode': inviteCode,
      'currency': currency,
      'members': memberIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// --- GROUP MEMBER MODEL ---
/// Represents a member within a group context.
/// This model combines the raw User ID with actual User data (Name, Email).
/// It is essential for the UI to display names like "Mario" instead of IDs like "user_123".
class GroupMember {
  final String uid;
  final String name;
  final String email;
  final String role; // e.g., 'admin' or 'member'
  final double balance; // Positive = owes money, Negative = is owed (future feature)

  GroupMember({
    required this.uid,
    required this.name,
    required this.email,
    this.role = 'member',
    this.balance = 0.0,
  });

  /// Helper factory to create a GroupMember from an AppUser object.
  factory GroupMember.fromUser(AppUser user, {String role = 'member'}) {
    return GroupMember(
      uid: user.uid,
      name: user.name,
      email: user.email,
      role: role,
    );
  }
}

// --- EXPENSE MODEL ---
/// Represents a single expense transaction (stored in the 'expenses' sub-collection).
class Expense {
  final String id;
  final String description;
  final double amount;
  final String payerId;
  final DateTime timestamp;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.payerId,
    required this.timestamp,
  });

  /// Factory method to create an Expense from a Firestore document.
  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      description: data['description'] ?? '',
      // Safely handle both int and double from Firestore
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      payerId: data['payerId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts the expense object to a Map for saving to Firestore.
  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'amount': amount,
      'payerId': payerId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}