import 'package:cloud_firestore/cloud_firestore.dart';

class SettleRequest {
  final String id;
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final String expenseId;
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime createdAt;

  SettleRequest({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.expenseId,
    required this.status,
    required this.createdAt,
  });

  factory SettleRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SettleRequest(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      fromUserId: data['fromUserId'] ?? '',
      toUserId: data['toUserId'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      expenseId: data['expenseId'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'expenseId': expenseId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
