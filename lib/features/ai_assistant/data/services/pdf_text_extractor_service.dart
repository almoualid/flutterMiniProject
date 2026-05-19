import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfTextExtractionException implements Exception {
  const PdfTextExtractionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PdfTextExtractorService {
  static const int maxCharactersForPrompt = 24000;
  static const int chunkSize = 6000;

  static Future<String> extractReadableText(
    Uint8List bytes, {
    String? fileName,
  }) async {
    if (bytes.isEmpty) {
      throw const PdfTextExtractionException(
        'Le fichier PDF est vide ou impossible a lire.',
      );
    }

    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final extractedText = PdfTextExtractor(document).extractText();
      final cleanText = cleanExtractedText(extractedText);

      if (!_hasReadableText(cleanText)) {
        throw const PdfTextExtractionException(
          'Impossible d\'extraire le texte de ce PDF. Le fichier peut etre scanne ou contenir des images.',
        );
      }

      return cleanText;
    } on PdfTextExtractionException {
      rethrow;
    } catch (_) {
      throw PdfTextExtractionException(
        'Impossible de lire le PDF${fileName == null ? '' : ' "$fileName"'}. Verifiez que le fichier n\'est pas protege ou corrompu.',
      );
    } finally {
      document?.dispose();
    }
  }

  static String cleanExtractedText(String text) {
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\t', ' ')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), ' ');

    final cleanedLines = normalized
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r' {2,}'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !_looksLikePdfTechnicalLine(line))
        .toList();

    return cleanedLines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static String buildAcademicSummaryPrompt(
    String courseText, {
    String? userInstruction,
  }) {
    final chunks = splitIntoChunks(courseText);
    final instruction =
        userInstruction == null || userInstruction.trim().isEmpty
        ? 'Resume le cours suivant en francais simple.'
        : userInstruction.trim();
    final buffer = StringBuffer()
      ..writeln('Tu es un assistant academique.')
      ..writeln(instruction)
      ..writeln('Donne :')
      ..writeln('1. Resume general')
      ..writeln('2. Points cles')
      ..writeln('3. Definitions importantes')
      ..writeln('4. Questions possibles d\'examen')
      ..writeln('5. Conseils de revision')
      ..writeln()
      ..writeln(
        'Utilise uniquement le texte lisible extrait du PDF ci-dessous. Ignore tout contenu technique ou metadonnees.',
      )
      ..writeln();

    if (chunks.length == 1) {
      buffer
        ..writeln('Voici le contenu du cours :')
        ..writeln(chunks.first);
    } else {
      buffer
        ..writeln(
          'Le cours est long. Resume chaque partie mentalement, puis donne une synthese globale finale.',
        )
        ..writeln();

      for (var i = 0; i < chunks.length; i++) {
        buffer
          ..writeln('--- Partie ${i + 1}/${chunks.length} ---')
          ..writeln(chunks[i])
          ..writeln();
      }
    }

    return buffer.toString();
  }

  static List<String> splitIntoChunks(String text) {
    final clippedText = text.length > maxCharactersForPrompt
        ? '${text.substring(0, maxCharactersForPrompt)}\n\n[Texte tronque pour respecter la limite de taille. Resume les informations disponibles.]'
        : text;

    final chunks = <String>[];
    var start = 0;
    while (start < clippedText.length) {
      var end = mathMin(start + chunkSize, clippedText.length);

      if (end < clippedText.length) {
        final lastParagraphBreak = clippedText.lastIndexOf('\n\n', end);
        final lastLineBreak = clippedText.lastIndexOf('\n', end);
        final splitAt = lastParagraphBreak > start + 1000
            ? lastParagraphBreak
            : lastLineBreak > start + 1000
            ? lastLineBreak
            : end;
        end = splitAt;
      }

      chunks.add(clippedText.substring(start, end).trim());
      start = end;
    }

    return chunks.where((chunk) => chunk.isNotEmpty).toList();
  }

  static int mathMin(int a, int b) => a < b ? a : b;

  static bool _hasReadableText(String text) {
    if (text.length < 80) return false;

    final letterMatches = RegExp(
      r'[A-Za-zÀ-ÖØ-öø-ÿ\u0600-\u06FF]',
      unicode: true,
    ).allMatches(text).length;

    return letterMatches >= 40;
  }

  static bool _looksLikePdfTechnicalLine(String line) {
    final lower = line.toLowerCase();

    return lower.startsWith('%pdf') ||
        lower == 'xref' ||
        lower == 'trailer' ||
        lower == 'startxref' ||
        lower == '%%eof' ||
        lower == 'stream' ||
        lower == 'endstream' ||
        RegExp(r'^\d+\s+\d+\s+obj$').hasMatch(lower) ||
        lower == 'endobj' ||
        lower.startsWith('/type ') ||
        lower.startsWith('/font') ||
        lower.startsWith('/filter') ||
        lower.startsWith('/length') ||
        lower.startsWith('/resources') ||
        lower.startsWith('/procset') ||
        lower.startsWith('/mediabox') ||
        lower.startsWith('<<') ||
        lower.startsWith('>>');
  }
}
