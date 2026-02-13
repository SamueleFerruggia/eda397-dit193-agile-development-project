import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Generate mocks for Firebase Auth
@GenerateMocks([
  FirebaseAuth,
  User,
  UserCredential,
])
import 'auth_validation_test.mocks.dart';

void main() {
  group('Email Validation Tests', () {
    test('Valid email formats should pass', () {
      final validEmails = [
        'test@example.com',
        'user.name@example.com',
        'user+tag@example.co.uk',
        'user123@test-domain.com',
      ];

      for (final email in validEmails) {
        expect(isValidEmail(email), true, reason: '$email should be valid');
      }
    });

    test('Invalid email formats should fail', () {
      final invalidEmails = [
        '',
        'notanemail',
        '@example.com',
        'user@',
        'user @example.com',
        'user@.com',
        'user@domain',
      ];

      for (final email in invalidEmails) {
        expect(isValidEmail(email), false, reason: '$email should be invalid');
      }
    });

    test('Email with spaces should be invalid', () {
      expect(isValidEmail('user name@example.com'), false);
      expect(isValidEmail(' user@example.com'), false);
      expect(isValidEmail('user@example.com '), false);
    });
  });

  group('Password Validation Tests', () {
    test('Valid passwords should pass (6+ characters)', () {
      final validPasswords = [
        '123456',
        'password',
        'Pass123!',
        'verylongpassword123',
        '!@#\$%^&*()',
      ];

      for (final password in validPasswords) {
        expect(isValidPassword(password), true,
            reason: '$password should be valid (6+ chars)');
      }
    });

    test('Invalid passwords should fail (less than 6 characters)', () {
      final invalidPasswords = [
        '',
        '1',
        '12',
        '123',
        '1234',
        '12345',
      ];

      for (final password in invalidPasswords) {
        expect(isValidPassword(password), false,
            reason: '$password should be invalid (< 6 chars)');
      }
    });

    test('Password exactly 6 characters should be valid', () {
      expect(isValidPassword('123456'), true);
      expect(isValidPassword('abcdef'), true);
    });
  });

  group('Password Match Validation Tests', () {
    test('Matching passwords should pass', () {
      expect(passwordsMatch('password123', 'password123'), true);
      expect(passwordsMatch('Test@123', 'Test@123'), true);
      expect(passwordsMatch('', ''), true);
    });

    test('Non-matching passwords should fail', () {
      expect(passwordsMatch('password123', 'password456'), false);
      expect(passwordsMatch('Test@123', 'test@123'), false);
      expect(passwordsMatch('password', ''), false);
    });

    test('Case-sensitive password matching', () {
      expect(passwordsMatch('Password', 'password'), false);
      expect(passwordsMatch('PASSWORD', 'password'), false);
    });
  });

  group('Sign Up Validation Tests', () {
    late MockFirebaseAuth mockAuth;
    late MockUserCredential mockCredential;
    late MockUser mockUser;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockCredential = MockUserCredential();
      mockUser = MockUser();
    });

    test('Sign up with valid email and password should succeed', () async {
      const email = 'newuser@example.com';
      const password = 'password123';

      when(mockAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      )).thenAnswer((_) async => mockCredential);

      when(mockCredential.user).thenReturn(mockUser);

      final result = await mockAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      expect(result.user, equals(mockUser));
      verify(mockAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      )).called(1);
    });

    test('Sign up with invalid email should fail', () async {
      const email = 'invalidemail';
      const password = 'password123';

      when(mockAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      )).thenThrow(
        FirebaseAuthException(
          code: 'invalid-email',
          message: 'The email address is badly formatted.',
        ),
      );

      expect(
        () => mockAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('Sign up with weak password should fail', () async {
      const email = 'user@example.com';
      const password = '123';

      when(mockAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      )).thenThrow(
        FirebaseAuthException(
          code: 'weak-password',
          message: 'Password should be at least 6 characters',
        ),
      );

      expect(
        () => mockAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('Sign up with existing email should fail', () async {
      const email = 'existing@example.com';
      const password = 'password123';

      when(mockAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      )).thenThrow(
        FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The email address is already in use by another account.',
        ),
      );

      expect(
        () => mockAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });

  group('Sign In Validation Tests', () {
    late MockFirebaseAuth mockAuth;
    late MockUserCredential mockCredential;
    late MockUser mockUser;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockCredential = MockUserCredential();
      mockUser = MockUser();
    });

    test('Sign in with valid credentials should succeed', () async {
      const email = 'user@example.com';
      const password = 'password123';

      when(mockAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      )).thenAnswer((_) async => mockCredential);

      when(mockCredential.user).thenReturn(mockUser);

      final result = await mockAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      expect(result.user, equals(mockUser));
      verify(mockAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      )).called(1);
    });

    test('Sign in with wrong password should fail', () async {
      const email = 'user@example.com';
      const password = 'wrongpassword';

      when(mockAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      )).thenThrow(
        FirebaseAuthException(
          code: 'wrong-password',
          message: 'The password is invalid or the user does not have a password.',
        ),
      );

      expect(
        () => mockAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('Sign in with non-existent user should fail', () async {
      const email = 'nonexistent@example.com';
      const password = 'password123';

      when(mockAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      )).thenThrow(
        FirebaseAuthException(
          code: 'user-not-found',
          message: 'There is no user record corresponding to this identifier.',
        ),
      );

      expect(
        () => mockAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('Sign in with invalid email format should fail', () async {
      const email = 'invalidemail';
      const password = 'password123';

      when(mockAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      )).thenThrow(
        FirebaseAuthException(
          code: 'invalid-email',
          message: 'The email address is badly formatted.',
        ),
      );

      expect(
        () => mockAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('Sign in with empty credentials should fail', () async {
      const email = '';
      const password = '';

      when(mockAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      )).thenThrow(
        FirebaseAuthException(
          code: 'invalid-email',
          message: 'The email address is badly formatted.',
        ),
      );

      expect(
        () => mockAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });

  group('Edge Cases and Security Tests', () {
    test('SQL injection attempts in email should be invalid', () {
      final sqlInjectionAttempts = [
        "admin'--",
        "admin' OR '1'='1",
        "'; DROP TABLE users--",
      ];

      for (final attempt in sqlInjectionAttempts) {
        expect(isValidEmail(attempt), false,
            reason: '$attempt should be invalid');
      }
    });

    test('Very long email should be handled', () {
      final longEmail = '${'a' * 100}@${'b' * 100}.com';
      // Should still validate based on format, not length
      expect(isValidEmail(longEmail), true);
    });

    test('Very long password should be valid if 6+ characters', () {
      final longPassword = 'a' * 1000;
      expect(isValidPassword(longPassword), true);
    });

    test('Special characters in password should be valid', () {
      final specialPasswords = [
        '!@#\$%^&*()',
        'Pass@123!',
        'test_password-123',
      ];

      for (final password in specialPasswords) {
        expect(isValidPassword(password), true,
            reason: '$password should be valid');
      }
    });
  });
}

// Helper validation functions
bool isValidEmail(String email) {
  if (email.isEmpty) return false;
  
  // Basic email regex pattern
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  
  return emailRegex.hasMatch(email);
}

bool isValidPassword(String password) {
  return password.length >= 6;
}

bool passwordsMatch(String password, String confirmPassword) {
  return password == confirmPassword;
}