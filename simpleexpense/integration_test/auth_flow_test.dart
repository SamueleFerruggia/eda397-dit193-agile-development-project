import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:simpleexpense/firebase_options.dart';
import 'package:simpleexpense/main.dart';
import 'package:simpleexpense/screens/login_screen.dart';
import 'package:simpleexpense/screens/signup_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize Firebase for the real app environment.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Make sure we start from a logged-out state.
    await FirebaseAuth.instance.signOut();
  });

  group('Auth flow integration tests', () {
    testWidgets('App starts on LoginScreen when user is logged out', (
      tester,
    ) async {
      await tester.pumpWidget(const MyApp());

      // Wait for authStateChanges StreamBuilder to settle.
      await tester.pumpAndSettle();

      // Verify that LoginScreen is shown (by title text).
      expect(find.text('Login'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Tapping "Create Account" navigates to SignupScreen', (
      tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // From LoginScreen, tap the "Create Account" button.
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Verify that the SignupScreen is displayed by its heading text.
      expect(find.byType(SignupScreen), findsOneWidget);
      expect(find.text('Create Account'), findsWidgets);
    });
  });
}
