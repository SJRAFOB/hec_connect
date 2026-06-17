import 'dart:convert';
import 'package:http/http.dart' as http;

/// Valide un code d'accès d'inscription via le serveur Render.
/// Le code n'est JAMAIS stocké dans le client — seul le serveur connaît les codes.
class CodeValidationService {
  static const String _serverUrl = 'https://hec-notify-server.onrender.com';

  /// Retourne `true` si le code est valide pour le [type] donné.
  /// [type] : "teacher" pour les profs, ou le nom du poste pour l'admin
  ///          (ex: "Fondateur", "Directeur", "Comptable", "Educateur", "Staff").
  /// Lance une [Exception] en cas de problème réseau — l'appelant doit gérer.
  static Future<bool> validate({required String type, required String code}) async {
    final response = await http.post(
      Uri.parse('$_serverUrl/validateCode'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'type': type, 'code': code}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Erreur serveur (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['valid'] == true;
  }
}
