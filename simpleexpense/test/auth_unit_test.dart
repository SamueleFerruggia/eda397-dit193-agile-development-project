import 'package:flutter_test/flutter_test.dart';

/// Unit tests for Email and Password Authentication
/// Simple validation tests without mocking or Firebase integration
/// To run it you can use this command: flutter test test/auth_unit_test.dart

void main() {
  group('Email Validation', () {
    test('Valid emails pass validation', () {
      expect(isValidEmail('test@example.com'), true);
      expect(isValidEmail('user.name@example.com'), true);
      expect(isValidEmail('user+tag@example.co.uk'), true);
      expect(isValidEmail('user123@test-domain.com'), true);
    });

    test('Invalid emails fail validation', () {
      expect(isValidEmail(''), false);
      expect(isValidEmail('notanemail'), false);
      expect(isValidEmail('@example.com'), false);
      expect(isValidEmail('user@'), false);
      expect(isValidEmail('user @example.com'), false);
    });
  });

  group('Password Validation', () {
    test('Valid passwords pass validation (6+ characters)', () {
      expect(isValidPassword('123456'), true);
      expect(isValidPassword('password'), true);
      expect(isValidPassword('Pass@123'), true);
    });

    test('Invalid passwords fail validation (< 6 characters)', () {
      expect(isValidPassword(''), false);
      expect(isValidPassword('12345'), false);
      expect(isValidPassword('abc'), false);
    });
  });

  group('Password Matching', () {
    test('Matching passwords return true', () {
      expect(passwordsMatch('password123', 'password123'), true);
      expect(passwordsMatch('Test@123', 'Test@123'), true);
    });

    test('Non-matching passwords return false', () {
      expect(passwordsMatch('password123', 'password456'), false);
      expect(passwordsMatch('Test@123', 'test@123'), false);
    });
  });

  group('Sign Up Validation', () {
    test('Valid sign up data passes all checks', () {
      const email = 'user@example.com';
      const password = 'password123';
      const confirmPassword = 'password123';

      expect(isValidEmail(email), true);
      expect(isValidPassword(password), true);
      expect(passwordsMatch(password, confirmPassword), true);
    });

    test('Invalid email fails sign up', () {
      expect(isValidEmail('invalidemail'), false);
    });

    test('Weak password fails sign up', () {
      expect(isValidPassword('123'), false);
    });

    test('Non-matching passwords fail sign up', () {
      expect(passwordsMatch('password123', 'password456'), false);
    });
  });

  group('Sign In Validation', () {
    test('Valid sign in data passes all checks', () {
      const email = 'user@example.com';
      const password = 'password123';

      expect(isValidEmail(email), true);
      expect(isValidPassword(password), true);
    });

    test('Empty email fails sign in', () {
      expect(isValidEmail(''), false);
    });

    test('Empty password fails sign in', () {
      expect(isValidPassword(''), false);
    });
  });
}

// Validation helper functions
bool isValidEmail(String email) {
  if (email.isEmpty) return false;
  final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  return emailRegex.hasMatch(email);
}

bool isValidPassword(String password) {
  return password.length >= 6;
}

bool passwordsMatch(String password, String confirmPassword) {
  return password == confirmPassword;
}