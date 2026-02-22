import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  final String groupId;
  final String description;
  final double amount;
  final String payerId;
  final String payerName;
  final List<String> splitWith;
  final String category;
  final String? notes;
  final String? receiptUrl;
  final DateTime timestamp;
  final DateTime? updatedAt;

  Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.payerId,
    required this.payerName,
    required this.splitWith,
    this.category = 'Other',
    this.notes,
    this.receiptUrl,
    required this.timestamp,
    this.updatedAt,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      payerId: data['payerId'] ?? '',
      payerName: data['payerName'] ?? '',
      splitWith: List<String>.from(data['splitWith'] ?? []),
      category: data['category'] ?? 'Other',
      notes: data['notes'],
      receiptUrl: data['receiptUrl'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'payerId': payerId,
      'payerName': payerName,
      'splitWith': splitWith,
      'category': category,
      'notes': notes,
      'receiptUrl': receiptUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Calculate the amount each person owes (equal split)
  double get amountPerPerson {
    if (splitWith.isEmpty) return amount;
    return amount / splitWith.length;
  }

  // Check if a specific user is involved in this expense
  bool involvesUser(String userId) {
    return payerId == userId || splitWith.contains(userId);
  }

  // Create a copy with updated fields
  Expense copyWith({
    String? id,
    String? groupId,
    String? description,
    double? amount,
    String? payerId,
    String? payerName,
    List<String>? splitWith,
    String? category,
    String? notes,
    String? receiptUrl,
    DateTime? timestamp,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      payerId: payerId ?? this.payerId,
      payerName: payerName ?? this.payerName,
      splitWith: splitWith ?? this.splitWith,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      timestamp: timestamp ?? this.timestamp,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Expense(id: $id, description: $description, amount: $amount, payerId: $payerId, splitWith: $splitWith)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Expense && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// --- GROUP INVITATION MODEL ---
class GroupInvitation {
  final String id;
  final String groupId;
  final String groupName;
  final String invitedBy;
  final String invitedByName;
  final String? invitedEmail;
  final String inviteCode;
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? respondedAt;

  GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.invitedBy,
    required this.invitedByName,
    this.invitedEmail,
    required this.inviteCode,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.respondedAt,
  });

  factory GroupInvitation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupInvitation(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      groupName: data['groupName'] ?? '',
      invitedBy: data['invitedBy'] ?? '',
      invitedByName: data['invitedByName'] ?? '',
      invitedEmail: data['invitedEmail'],
      inviteCode: data['inviteCode'] ?? '',
      status: InvitationStatus.fromString(data['status'] ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'invitedBy': invitedBy,
      'invitedByName': invitedByName,
      'invitedEmail': invitedEmail,
      'inviteCode': inviteCode,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isPending => status == InvitationStatus.pending && !isExpired;

  GroupInvitation copyWith({
    String? id,
    String? groupId,
    String? groupName,
    String? invitedBy,
    String? invitedByName,
    String? invitedEmail,
    String? inviteCode,
    InvitationStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? respondedAt,
  }) {
    return GroupInvitation(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      invitedBy: invitedBy ?? this.invitedBy,
      invitedByName: invitedByName ?? this.invitedByName,
      invitedEmail: invitedEmail ?? this.invitedEmail,
      inviteCode: inviteCode ?? this.inviteCode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}

// --- INVITATION STATUS ENUM ---
enum InvitationStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined'),
  expired('expired'),
  revoked('revoked');

  final String value;
  const InvitationStatus(this.value);

  static InvitationStatus fromString(String value) {
    return InvitationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => InvitationStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case InvitationStatus.pending:
        return 'Pending';
      case InvitationStatus.accepted:
        return 'Accepted';
      case InvitationStatus.declined:
        return 'Declined';
      case InvitationStatus.expired:
        return 'Expired';
      case InvitationStatus.revoked:
        return 'Revoked';
    }
  }

  Color get color {
    switch (this) {
      case InvitationStatus.pending:
        return Colors.orange;
      case InvitationStatus.accepted:
        return Colors.green;
      case InvitationStatus.declined:
        return Colors.red;
      case InvitationStatus.expired:
        return Colors.grey;
      case InvitationStatus.revoked:
        return Colors.grey;
    }
  }
}