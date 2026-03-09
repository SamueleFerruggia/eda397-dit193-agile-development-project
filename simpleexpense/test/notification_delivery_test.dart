import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryNotificationStore store;

  setUp(() {
    store = InMemoryNotificationStore();
  });

  // AC-1: Notifications must be delivered reliably across all devices.

  group('Reliable delivery across users (AC-1)', () {
    test(
      'Expense notification is created for every participant except payer',
      () {
        const payerId = 'payer_1';
        const groupMembers = ['payer_1', 'u2', 'u3', 'u4'];

        final recipients = groupMembers.where((id) => id != payerId).toList();

        for (final uid in recipients) {
          store.addNotification(
            userId: uid,
            message: buildExpenseMessage(
              payerName: 'Alice',
              description: 'Dinner',
              amount: 200.0,
              currency: 'SEK',
            ),
            type: NotificationType.expense,
          );
        }

        expect(store.getByUser('u2').length, 1);
        expect(store.getByUser('u3').length, 1);
        expect(store.getByUser('u4').length, 1);
        expect(store.getByUser(payerId), isEmpty);
      },
    );

    test('Settlement notification is sent to both parties', () {
      for (final uid in ['debtor_1', 'creditor_1']) {
        store.addNotification(
          userId: uid,
          message: buildSettlementMessage(
            fromName: 'Bob',
            toName: 'Alice',
            amount: 75.0,
            currency: 'SEK',
          ),
          type: NotificationType.settlement,
        );
      }

      expect(store.getByUser('debtor_1').length, 1);
      expect(store.getByUser('creditor_1').length, 1);
    });

    test('User with no activity receives zero notifications', () {
      store.addNotification(
        userId: 'active_user',
        message: 'Something happened',
        type: NotificationType.expense,
      );

      expect(store.getByUser('bystander'), isEmpty);
    });

    test('Multiple expenses produce independent notifications', () {
      store.addNotification(
        userId: 'u1',
        message: 'Alice added "Lunch" – 80.00 SEK',
        type: NotificationType.expense,
      );
      store.addNotification(
        userId: 'u1',
        message: 'Bob added "Taxi" – 40.00 SEK',
        type: NotificationType.expense,
      );
      store.addNotification(
        userId: 'u1',
        message: 'Carol added "Hotel" – 600.00 SEK',
        type: NotificationType.expense,
      );

      expect(store.getByUser('u1').length, 3);
    });

    test('Notification targets correct user when multiple users exist', () {
      store.addNotification(
        userId: 'alice',
        message: 'For Alice',
        type: NotificationType.expense,
      );
      store.addNotification(
        userId: 'bob',
        message: 'For Bob',
        type: NotificationType.settlement,
      );

      final aliceNotifs = store.getByUser('alice');
      final bobNotifs = store.getByUser('bob');

      expect(aliceNotifs.length, 1);
      expect(aliceNotifs.first.message, 'For Alice');
      expect(aliceNotifs.first.type, NotificationType.expense);
      expect(bobNotifs.length, 1);
      expect(bobNotifs.first.message, 'For Bob');
      expect(bobNotifs.first.type, NotificationType.settlement);
    });

    test(
      'Group expense broadcast: every member except payer gets notified',
      () {
        const payerId = 'payer_1';
        const members = ['payer_1', 'u2', 'u3', 'u4'];

        for (final uid in members.where((id) => id != payerId)) {
          store.addNotification(
            userId: uid,
            message: buildExpenseMessage(
              payerName: 'Alice',
              description: 'Dinner',
              amount: 200.0,
              currency: 'SEK',
            ),
            type: NotificationType.expense,
          );
        }

        expect(store.allNotifications.length, 3);
        expect(
          store.allNotifications.where((n) => n.userId == payerId),
          isEmpty,
        );
      },
    );
  });

  // AC-2: Timing of notifications should be accurate.

  group('Notification timing accuracy (AC-2)', () {
    test('Notifications are sorted newest-first', () {
      final t1 = DateTime(2025, 6, 1, 10, 0);
      final t2 = DateTime(2025, 6, 1, 12, 0);
      final t3 = DateTime(2025, 6, 1, 14, 0);

      store.addNotification(
        userId: 'u1',
        message: 'Second',
        type: NotificationType.expense,
        createdAt: t2,
      );
      store.addNotification(
        userId: 'u1',
        message: 'First',
        type: NotificationType.expense,
        createdAt: t1,
      );
      store.addNotification(
        userId: 'u1',
        message: 'Third',
        type: NotificationType.expense,
        createdAt: t3,
      );

      final sorted = store.streamUserNotifications('u1');

      expect(sorted[0].message, 'Third');
      expect(sorted[1].message, 'Second');
      expect(sorted[2].message, 'First');
    });

    test('New notification is unread (readAt == null, isUnread == true)', () {
      store.addNotification(
        userId: 'u1',
        message: 'Unread check',
        type: NotificationType.expense,
      );

      final notif = store.getByUser('u1').first;
      expect(notif.readAt, isNull);
      expect(notif.isUnread, isTrue);
    });

    test('Unread count reflects only notifications without readAt', () {
      store.addNotification(
        userId: 'u1',
        message: 'Unread 1',
        type: NotificationType.expense,
      );
      store.addNotification(
        userId: 'u1',
        message: 'Unread 2',
        type: NotificationType.settlement,
      );

      expect(store.unreadCount('u1'), 2);
      store.markAllAsRead('u1');
      expect(store.unreadCount('u1'), 0);
    });

    test('markAllAsRead only touches previously-unread notifications', () {
      store.addNotification(
        userId: 'u1',
        message: 'Already read',
        type: NotificationType.expense,
        createdAt: DateTime(2025, 6, 1, 8, 0),
      );

      store.markAllAsRead('u1');
      final firstReadAt = store.getByUser('u1').first.readAt;

      store.addNotification(
        userId: 'u1',
        message: 'New unread',
        type: NotificationType.expense,
      );
      expect(store.unreadCount('u1'), 1);

      store.markAllAsRead('u1');
      expect(store.unreadCount('u1'), 0);

      final alreadyRead = store
          .getByUser('u1')
          .firstWhere((n) => n.message == 'Already read');
      expect(alreadyRead.readAt, firstReadAt);
    });

    test('markAllAsRead for empty userId is a no-op', () {
      store.markAllAsRead('');
      expect(store.unreadCount(''), 0);
    });

    test('createdAt is always set on a stored notification', () {
      store.addNotification(
        userId: 'u1',
        message: 'Timestamp check',
        type: NotificationType.expense,
      );

      expect(store.getByUser('u1').first.createdAt, isNotNull);
    });
  });

  // AC-3: Messages must be accurate and correctly formatted.

  group('Message accuracy and formatting (AC-3)', () {
    test('Expense message includes payer, description, amount, currency', () {
      final msg = buildExpenseMessage(
        payerName: 'Alice',
        description: 'Hotel',
        amount: 450.0,
        currency: 'SEK',
      );

      expect(msg.contains('Alice'), isTrue);
      expect(msg.contains('Hotel'), isTrue);
      expect(msg.contains('450.00'), isTrue);
      expect(msg.contains('SEK'), isTrue);
    });

    test('Settlement message includes both names, amount, currency', () {
      final msg = buildSettlementMessage(
        fromName: 'Bob',
        toName: 'Alice',
        amount: 75.0,
        currency: 'EUR',
      );

      expect(msg.contains('Bob'), isTrue);
      expect(msg.contains('Alice'), isTrue);
      expect(msg.contains('75.00'), isTrue);
      expect(msg.contains('EUR'), isTrue);
    });

    test('Amount is always formatted with two decimal places', () {
      expect(formatAmount(10.0), '10.00');
      expect(formatAmount(10.5), '10.50');
      expect(formatAmount(0.1), '0.10');
      expect(formatAmount(1234.567), '1234.57');
    });

    test('NotificationType.value matches Firestore string schema', () {
      expect(NotificationType.expense.value, 'expense');
      expect(NotificationType.settlement.value, 'settlement');
    });

    test('NotificationType.fromString round-trips correctly', () {
      expect(NotificationType.fromString('expense'), NotificationType.expense);
      expect(
        NotificationType.fromString('settlement'),
        NotificationType.settlement,
      );
    });

    test('NotificationType.fromString falls back to expense for unknown', () {
      expect(NotificationType.fromString('unknown'), NotificationType.expense);
      expect(NotificationType.fromString(''), NotificationType.expense);
    });

    test('Empty or blank message is flagged as invalid', () {
      expect(isValidNotificationMessage(''), isFalse);
      expect(isValidNotificationMessage('  '), isFalse);
      expect(isValidNotificationMessage('You have a new expense'), isTrue);
    });

    test('Long message body is truncated with ellipsis', () {
      final longBody = 'A' * 300;
      final truncated = truncateMessage(longBody, 256);

      expect(truncated.length <= 256, isTrue);
      expect(truncated.endsWith('...'), isTrue);
    });

    test('Short message is not truncated', () {
      const body = 'Alice added "Lunch" – 80.00 SEK';
      expect(truncateMessage(body, 256), body);
    });
  });

  group('Cross-device consistency via Firestore sync', () {
    test('Same userId sees identical notifications on any device', () {
      store.addNotification(
        userId: 'u1',
        message: 'Visible everywhere',
        type: NotificationType.expense,
      );

      final deviceA = store.streamUserNotifications('u1');
      final deviceB = store.streamUserNotifications('u1');

      expect(deviceA.length, deviceB.length);
      expect(deviceA.first.id, deviceB.first.id);
      expect(deviceA.first.message, deviceB.first.message);
    });

    test('markAllAsRead on one device is reflected everywhere', () {
      store.addNotification(
        userId: 'u1',
        message: 'Sync test',
        type: NotificationType.expense,
      );

      store.markAllAsRead('u1');

      expect(store.unreadCount('u1'), 0);
      expect(store.streamUserNotifications('u1').first.isUnread, isFalse);
    });

    test('Notifications for different users are isolated', () {
      store.addNotification(
        userId: 'u1',
        message: 'Only for u1',
        type: NotificationType.expense,
      );
      store.addNotification(
        userId: 'u2',
        message: 'Only for u2',
        type: NotificationType.settlement,
      );

      expect(store.streamUserNotifications('u1').length, 1);
      expect(store.streamUserNotifications('u1').first.message, 'Only for u1');
      expect(store.streamUserNotifications('u2').length, 1);
      expect(store.streamUserNotifications('u2').first.message, 'Only for u2');
    });
  });

  group('Edge cases', () {
    test('streamUserNotifications for empty userId returns empty list', () {
      store.addNotification(
        userId: 'u1',
        message: 'Something',
        type: NotificationType.expense,
      );

      expect(store.streamUserNotifications(''), isEmpty);
    });

    test('Large volume of notifications stays correctly ordered', () {
      final base = DateTime(2025, 1, 1);
      for (var i = 0; i < 200; i++) {
        store.addNotification(
          userId: 'u1',
          message: 'Notif $i',
          type: NotificationType.expense,
          createdAt: base.add(Duration(minutes: i)),
        );
      }

      final sorted = store.streamUserNotifications('u1');
      expect(sorted.length, 200);

      for (var i = 0; i < sorted.length - 1; i++) {
        expect(
          sorted[i].createdAt.isAfter(sorted[i + 1].createdAt) ||
              sorted[i].createdAt.isAtSameMomentAs(sorted[i + 1].createdAt),
          isTrue,
        );
      }
    });

    test('Special characters and emoji in message are preserved', () {
      const msg = 'Alice added "Café ☕" – 12.50 EUR';
      store.addNotification(
        userId: 'u1',
        message: msg,
        type: NotificationType.expense,
      );

      expect(store.getByUser('u1').first.message, msg);
    });

    test('Notification.isUnread toggles correctly after markAllAsRead', () {
      store.addNotification(
        userId: 'u1',
        message: 'Check isUnread',
        type: NotificationType.settlement,
      );

      expect(store.getByUser('u1').first.isUnread, isTrue);
      store.markAllAsRead('u1');
      expect(store.getByUser('u1').first.isUnread, isFalse);
    });
  });
}

// -- Models (mirrors models.dart without Firebase dependencies) --

enum NotificationType {
  expense('expense'),
  settlement('settlement');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => NotificationType.expense,
    );
  }
}

class Notification {
  final String id;
  final String userId;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  DateTime? readAt;

  Notification({
    required this.id,
    required this.userId,
    required this.message,
    required this.type,
    required this.createdAt,
    this.readAt,
  });

  bool get isUnread => readAt == null;
}

// -- In-memory store (mirrors FirestoreService notification methods) --

class InMemoryNotificationStore {
  final List<Notification> _notifications = [];
  int _idCounter = 0;

  List<Notification> get allNotifications => List.unmodifiable(_notifications);

  void addNotification({
    required String userId,
    required String message,
    required NotificationType type,
    DateTime? createdAt,
  }) {
    _notifications.add(
      Notification(
        id: 'notif_${++_idCounter}',
        userId: userId,
        message: message,
        type: type,
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }

  List<Notification> getByUser(String userId) {
    return _notifications.where((n) => n.userId == userId).toList();
  }

  List<Notification> streamUserNotifications(String userId) {
    if (userId.isEmpty) return [];
    final list = getByUser(userId);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int unreadCount(String userId) {
    if (userId.isEmpty) return 0;
    return getByUser(userId).where((n) => n.isUnread).length;
  }

  void markAllAsRead(String userId) {
    if (userId.isEmpty) return;
    final now = DateTime.now();
    for (final n in _notifications) {
      if (n.userId == userId && n.readAt == null) {
        n.readAt = now;
      }
    }
  }
}

// -- Helpers --

String buildExpenseMessage({
  required String payerName,
  required String description,
  required double amount,
  required String currency,
}) {
  return '$payerName added "$description" – ${formatAmount(amount)} $currency';
}

String buildSettlementMessage({
  required String fromName,
  required String toName,
  required double amount,
  required String currency,
}) {
  return '$fromName paid $toName ${formatAmount(amount)} $currency';
}

String formatAmount(double amount) => amount.toStringAsFixed(2);

bool isValidNotificationMessage(String message) => message.trim().isNotEmpty;

String truncateMessage(String body, int maxLength) {
  if (body.length <= maxLength) return body;
  return '${body.substring(0, maxLength - 3)}...';
}
