import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:student_companion/features/auth/data/services/auth_service.dart';
import 'package:student_companion/features/auth/domain/models/auth_failure.dart';

/// Authentication state managed by this enum.
enum AuthStatus { initial, authenticated, unauthenticated, loading }

/// Presentation layer: exposes auth state and actions to the UI.
/// Wraps [AuthService] and manages loading / error state.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;

  AuthProvider({required AuthService authService})
      : _authService = authService {
    // Listen to Firebase auth state persistently (auto-login).
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    _user = user;
    _status =
        user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  /// Returns true on success, false on failure (error stored in [errorMessage]).
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading();
    try {
      await _authService.signIn(email: email, password: password);
      _clearError();
      return true;
    } on AuthFailure catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Returns true on success, false on failure.
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    _setLoading();
    try {
      await _authService.signUp(email: email, password: password);
      _clearError();
      return true;
    } on AuthFailure catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
