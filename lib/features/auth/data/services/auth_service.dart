import 'package:firebase_auth/firebase_auth.dart';
import 'package:student_companion/features/auth/domain/models/auth_failure.dart';

/// Data layer : wraps FirebaseAuth and exposes clean async methods.
/// Throws [AuthFailure] on every error so callers never deal with Firebase directly.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  /// Stream of auth-state changes; emits [User?] on every change.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Returns the currently signed-in user, or null.
  User? get currentUser => _auth.currentUser;

  /// Creates a new account with [email] and [password].
  Future<User> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    } catch (_) {
      throw const AuthFailure('Une erreur inattendue s\'est produite.');
    }
  }

  /// Signs in an existing user with [email] and [password].
  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    } catch (_) {
      throw const AuthFailure('Une erreur inattendue s\'est produite.');
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
