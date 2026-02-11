import 'package:cloud_firestore/cloud_firestore.dart';

// --- USER MODEL ---
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

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// --- GROUP MODEL ---
class Group {
  final String id;
  final String name;
  final String adminId;
  final String inviteCode;
  final String currency;
  final List<String> memberIds;
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

  factory Group.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      name: data['groupName'] ?? '',
      adminId: data['adminId'] ?? '',
      inviteCode: data['inviteCode'] ?? '',
      currency: data['currency'] ?? 'SEK',
      memberIds: List<String>.from(data['members'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

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
class GroupMember {
  final String uid;
  final String name;
  final String email;
  final String role;
  final double balance;

  GroupMember({
    required this.uid,
    required this.name,
    required this.email,
    this.role = 'member',
    this.balance = 0.0,
  });

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
class Expense {
  final String id;
  final String description;
  final double amount;
  final String payerId;
  final List<String> splitWith; // New field for split logic
  final DateTime timestamp;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.payerId,
    required this.splitWith,
    required this.timestamp,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      description: data['description'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      payerId: data['payerId'] ?? '',
      splitWith: List<String>.from(data['splitWith'] ?? []),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'amount': amount,
      'payerId': payerId,
      'splitWith': splitWith,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}