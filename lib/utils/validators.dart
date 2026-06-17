/// Validateurs de formulaires
class Validators {
  /// Valide une adresse email
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez saisir votre email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email invalide';
    }
    return null;
  }

  /// Valide un mot de passe (min 8 caractères)
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez saisir un mot de passe';
    }
    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    return null;
  }

  /// Valide qu'un champ n'est pas vide
  static String? notEmpty(String? value, {String fieldName = 'Ce champ'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est requis';
    }
    return null;
  }

  /// Valide la confirmation du mot de passe
  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) {
      return 'Veuillez confirmer le mot de passe';
    }
    if (value != original) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  /// Valide un matricule HEC
  /// Format accepté : lettres, chiffres, tirets, entre 5 et 20 caractères.
  static String? matricule(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le matricule est requis';
    }
    final trimmed =