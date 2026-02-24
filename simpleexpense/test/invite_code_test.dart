import 'package:flutter_test/flutter_test.dart';

/// Invite code format used when joining a group: 6 alphanumeric chars (uppercase).
void main() {
  group('Invite code validation', () {
    test('Valid 6-character alphanumeric codes pass', () {
      expect(isValidInviteCode('ABC123'), true);
      expect(isValidInviteCode('XYZ789'), true);
      expect(isValidInviteCode('000000'), true);
      expect(isValidInviteCode('AAAAAA'), true);
    });

    test('Too short or too long codes fail', () {
      expect(isValidInviteCode(''), false);
      expect(isValidInviteCode('ABC12'), false);
      expect(isValidInviteCode('ABC1234'), false);
    });

    test('Lowercase or invalid characters fail', () {
      expect(isValidInviteCode('abc123'), false);
      expect(isValidInviteCode('ABC-12'), false);
      expect(isValidInviteCode('ABC 12'), false);
    });
  });
}

bool isValidInviteCode(String code) {
  if (code.length != 6) return false;
  return RegExp(r'^[A-Z0-9]+$').hasMatch(code);
}
