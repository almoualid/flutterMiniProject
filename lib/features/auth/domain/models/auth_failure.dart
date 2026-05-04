/// Represents authentication-specific failures with user-friendly messages.
class AuthFailure {
  final String message;
  const AuthFailure(this.message);

  /// Maps Firebase error codes to human-readable messages.
  factory AuthFailure.fromCode(String code) {
    return switch (code) {
      'invalid-email' => const AuthFailure('L\'adresse email est invalide.'),
      'user-disabled' => const AuthFailure('Ce compte a été désactivé.'),
      'user-not-found' => const AuthFailure('Aucun compte trouvé avec cet email.'),
      'wrong-password' => const AuthFailure('Mot de passe incorrect.'),
      'email-already-in-use' => const AuthFailure('Un compte existe déjà avec cet email.'),
      'weak-password' => const AuthFailure('Le mot de passe doit contenir au moins 6 caractères.'),
      'operation-not-allowed' => const AuthFailure('Opération non autorisée. Contactez le support.'),
      'too-many-requests' => const AuthFailure('Trop de tentatives. Réessayez plus tard.'),
      'network-request-failed' => const AuthFailure('Erreur réseau. Vérifiez votre connexion.'),
      'invalid-credential' => const AuthFailure('Email ou mot de passe incorrect.'),
      _ => const AuthFailure('Une erreur inattendue s\'est produite.'),
    };
  }
}
