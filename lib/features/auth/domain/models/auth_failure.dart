/// Represents authentication-specific failures with user-friendly messages.
class AuthFailure {
  final String message;
  const AuthFailure(this.message);

  /// Maps Firebase error codes to human-readable messages.
  factory AuthFailure.fromCode(String code) {
    return switch (code) {
      'invalid-email' => const AuthFailure(
          'L\'adresse email saisie est incorrecte.',
        ),
      'user-disabled' => const AuthFailure(
          'Ce compte utilisateur a été désactivé.',
        ),
      'user-not-found' => const AuthFailure(
          'Aucun compte n\'est associé à cet email.',
        ),
      'wrong-password' => const AuthFailure(
          'Le mot de passe saisi est incorrect.',
        ),
      'email-already-in-use' => const AuthFailure(
          'Cet email est déjà utilisé par un autre compte.',
        ),
      'weak-password' => const AuthFailure(
          'Le mot de passe doit être plus fort : utilisez au moins 8 caractères, des lettres, des chiffres et un symbole.',
        ),
      'operation-not-allowed' => const AuthFailure(
          'L\'authentification par email n\'est pas activée.',
        ),
      'too-many-requests' => const AuthFailure(
          'Trop de tentatives échouées. Veuillez patienter.',
        ),
      'network-request-failed' => const AuthFailure(
          'Erreur réseau. Vérifiez votre connexion internet.',
        ),
      'invalid-credential' => const AuthFailure(
          'Email ou mot de passe incorrect.',
        ),
      'channel-error' => const AuthFailure(
          'Veuillez remplir tous les champs requis.',
        ),
      _ => const AuthFailure('Une erreur de sécurité est survenue. Réessayez.'),
    };
  }
}
