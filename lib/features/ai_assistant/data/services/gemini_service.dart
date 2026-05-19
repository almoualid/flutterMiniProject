import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class GeminiService {
  static const _apiKey = 'AIzaSyDuDJvrfsfPNy_lY8JIOT8-T8EOvZPa-UM';
  static const _geminiModel = 'gemini-2.5-flash';

  static const _systemPrompt = '''
Tu es StudyBot, un assistant académique intelligent intégré dans l'application Student Companion.

Ton rôle est d'aider les étudiants à réussir leurs études en :
  - Résumant des notes de cours de manière structurée et claire
  - Créant des plannings d'étude personnalisés et réalistes
  - Expliquant des concepts académiques avec des exemples simples
  - Suggérant des techniques de révision efficaces (Pomodoro, répétition espacée, mind maps, etc.)
  - Répondant à des questions sur toutes les matières académiques

Règles importantes :
  - Réponds TOUJOURS dans la même langue que l'étudiant (arabe, français ou anglais)
  - Sois encourageant, positif et motivant
  - Structure tes réponses avec des titres et des listes quand c'est utile
  - Si une question n'est pas académique, redirige poliment vers les études
  - Garde tes réponses concises mais complètes
''';

  static final GenerativeModel _model = GenerativeModel(
    model: _geminiModel,
    apiKey: _apiKey,
    systemInstruction: Content.system(_systemPrompt),
    generationConfig: GenerationConfig(
      temperature: 0.7,
      maxOutputTokens: 1024,
    ),
  );

  static Future<String> sendMessage(List<ChatMessage> history) async {
    if (_apiKey.isEmpty) {
      return '⚠️ Clé API manquante.';
    }

    try {
      final geminiHistory = history
          .where((m) => !m.isLoading)
          .map((m) => Content(
                m.role == MessageRole.user ? 'user' : 'model',
                [TextPart(m.apiContent)],
              ))
          .toList();

      final previousMessages =
          geminiHistory.sublist(0, geminiHistory.length - 1);
      final lastApiContent = history.last.apiContent; 

      final chat = _model.startChat(history: previousMessages);
      final response = await chat.sendMessage(Content.text(lastApiContent));

      return response.text ?? 'Je n\'ai pas pu générer une réponse. Réessaie.';

    } on GenerativeAIException catch (e) {
      return '❌ Erreur Gemini : ${e.message}';
    } catch (e) {
      return '❌ Erreur de connexion. Vérifie ta connexion internet et réessaie.';
    }
  }

  static Future<String> summarizePdf(Uint8List pdfBytes) async {
    if (_apiKey.isEmpty) {
      return '⚠️ Clé API manquante.';
    }

    try {
      if (pdfBytes.isEmpty) {
        return '❌ Le fichier PDF est vide ou impossible à lire.';
      }

      final base64Pdf = base64Encode(pdfBytes);
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_apiKey',
      );

      final body = {
        'contents': [
          {
            'parts': [
              {
                'inline_data': {
                  'mime_type': 'application/pdf',
                  'data': base64Pdf,
                },
              },
              {
                'text': '''
Tu es un assistant académique intelligent.
Analyse ce fichier PDF de cours et donne un résumé clair en français.

Donne:
1. Résumé général
2. Points importants
3. Définitions clés
4. Plan du cours
5. 5 questions de révision avec réponses
''',
              },
            ],
          },
        ],
      };

      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return '❌ Erreur Gemini : ${response.body}';
        }
        return 'Impossible de lire la réponse de Gemini.';
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
        final message = error is Map<String, dynamic>
            ? error['message']?.toString()
            : null;
        return '❌ Erreur Gemini : ${message ?? response.body}';
      }

      if (decoded is! Map<String, dynamic>) {
        return 'Impossible de lire la réponse de Gemini.';
      }

      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        return 'Impossible de lire la réponse de Gemini.';
      }

      final firstCandidate = candidates.first;
      if (firstCandidate is! Map<String, dynamic>) {
        return 'Impossible de lire la réponse de Gemini.';
      }

      final content = firstCandidate['content'];
      final parts = content is Map<String, dynamic> ? content['parts'] : null;
      if (parts is! List || parts.isEmpty) {
        return 'Impossible de lire la réponse de Gemini.';
      }

      final firstPart = parts.first;
      if (firstPart is! Map<String, dynamic>) {
        return 'Impossible de lire la réponse de Gemini.';
      }

      final text = firstPart['text'];
      if (text is! String || text.trim().isEmpty) {
        return 'Impossible de lire la réponse de Gemini.';
      }

      return text;
    } on FormatException {
      return 'Impossible de lire la réponse de Gemini.';
    } catch (e) {
      return '❌ Erreur de connexion. Vérifie ta connexion internet et réessaie.';
    }
  }
}
