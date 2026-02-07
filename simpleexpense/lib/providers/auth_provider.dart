import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  // Obscure text state for password fields
  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;

  bool _obscureConfirmPassword = true;
  bool get obscureConfirmPassword => _obscureConfirmPassword;

  // Loading state for async operations
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void toggleObscure() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void toggleObscureConfirm() {
    _obscureConfirmPassword = !_obscureConfirmPassword;
    notifyListeners();
  }

  // Helper function for setting loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Login
  Future<String?> login(String email, String password) async {
    _setLoading(true);
    try {
      await _authService.signIn(email: email, password: password);
      _setLoading(false);
      return null; // Null means success
    } catch (e) {
      _setLoading(false);
      return e.toString(); // Return error message as string
    }
  }

  // Signup
  Future<String?> signUp(String email, String password, String name) async {
    _setLoading(true);
    try {
      // 1. Create Auth User
      User? user = await _authService.signUp(email: email, password: password, name: name);
      
      // 2. If Auth ok, save in Database
      if (user != null) {
        await _firestoreService.saveUser(user.uid, email, name);
      }

      _setLoading(false);
      return null; // Success
    } catch (e) {
      _setLoading(false);
      return e.toString();
    }
  }

  // Logout
  Future<void> logout() async {
    await _authService.signOut();
  }
}
