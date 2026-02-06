import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream for listening to auth state changes (Logged in / Not logged in)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Obtain the current user
  User? get currentUser => _auth.currentUser;

  // Sign Up
  Future<User?> signUp({required String email, required String password, required String name}) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      User? user = result.user;
      // Update immediately the Display Name of Firebase Auth
      await user?.updateDisplayName(name);
      return user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An unknown error occurred during sign up.';
    }
  }

  // Sign In
  Future<User?> signIn({required String email, required String password}) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An unknown error occurred during login.';
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}