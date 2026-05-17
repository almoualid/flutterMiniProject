// lib/services/local_service.dart

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class LocalService {
  static final LocalService _instance = LocalService._internal();
  factory LocalService() => _instance;
  LocalService._internal();

  static const String coursesBoxName    = 'courses_box';
  static const String homeworksBoxName  = 'homeworks_box';
  
  static const String metaBoxName       = 'meta_box';

  // Clés dans la meta box
  static const String _pendingCourseDeletesKey   = 'pending_course_deletes';
  static const String _pendingHomeworkDeletesKey = 'pending_homework_deletes';

  // ── Accès aux boxes (ouvertes par main.dart) ───────────────────────────────
  Box<String> get coursesBox   => Hive.box<String>(coursesBoxName);
  Box<String> get homeworksBox => Hive.box<String>(homeworksBoxName);
  Box<String> get metaBox      => Hive.box<String>(metaBoxName);

  // ══════════════════════════════════════════════════════════════════════════
  //  COURS
  // ══════════════════════════════════════════════════════════════════════════

  /// Retourne tous les cours stockés localement
  List<Map<String, dynamic>> getAllCourses() {
    return coursesBox.values
        .map((jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>)
        .toList();
  }

  /// Retourne un cours par son ID
  Map<String, dynamic>? getCourseById(String id) {
    final jsonStr = coursesBox.get(id);
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// Sauvegarde un cours (insert ou update selon si l'ID existe)
  Future<void> saveCourse(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    await coursesBox.put(id, jsonEncode(data));
  }

  /// Sauvegarde une liste de cours (ex : données venant de Firebase)
  Future<void> saveCoursesBatch(List<Map<String, dynamic>> courses) async {
    for (final course in courses) {
      await saveCourse(course);
    }
  }

  /// Supprime un cours du stockage local
  Future<void> deleteCourse(String id) async {
    await coursesBox.delete(id);
  }

  /// Vrai si le stockage cours est vide
  bool get isCoursesEmpty => coursesBox.isEmpty;

  // ══════════════════════════════════════════════════════════════════════════
  //  DEVOIRS
  // ══════════════════════════════════════════════════════════════════════════

  /// Retourne tous les devoirs stockés localement
  List<Map<String, dynamic>> getAllHomeworks() {
    return homeworksBox.values
        .map((jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>)
        .toList();
  }

  /// Retourne un devoir par son ID
  Map<String, dynamic>? getHomeworkById(String id) {
    final jsonStr = homeworksBox.get(id);
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// Sauvegarde un devoir
  Future<void> saveHomework(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    await homeworksBox.put(id, jsonEncode(data));
  }

  /// Sauvegarde une liste de devoirs
  Future<void> saveHomeworksBatch(List<Map<String, dynamic>> homeworks) async {
    for (final hw in homeworks) {
      await saveHomework(hw);
    }
  }

  /// Supprime un devoir du stockage local
  Future<void> deleteHomework(String id) async {
    await homeworksBox.delete(id);
  }

  /// Vrai si le stockage devoirs est vide
  bool get isHomeworksEmpty => homeworksBox.isEmpty;

  // ══════════════════════════════════════════════════════════════════════════
  //  SUPPRESSIONS EN ATTENTE (offline deletes)
  //  Quand on supprime un élément hors ligne, on stocke son ID ici.
  //  À la reconnexion, SyncService viendra supprimer sur Firebase.
  // ══════════════════════════════════════════════════════════════════════════

  List<String> _loadList(String key) {
    final jsonStr = metaBox.get(key);
    if (jsonStr == null) return [];
    return (jsonDecode(jsonStr) as List).cast<String>();
  }

  Future<void> _saveList(String key, List<String> ids) async {
    await metaBox.put(key, jsonEncode(ids));
  }

  // ── Cours ──────────────────────────────────────────────────────────────────
  List<String> getPendingCourseDeletes() =>
      _loadList(_pendingCourseDeletesKey);

  Future<void> addPendingCourseDelete(String id) async {
    final ids = getPendingCourseDeletes();
    if (!ids.contains(id)) {
      ids.add(id);
      await _saveList(_pendingCourseDeletesKey, ids);
    }
  }

  Future<void> removePendingCourseDelete(String id) async {
    final ids = getPendingCourseDeletes()..remove(id);
    await _saveList(_pendingCourseDeletesKey, ids);
  }

  // ── Devoirs ────────────────────────────────────────────────────────────────
  List<String> getPendingHomeworkDeletes() =>
      _loadList(_pendingHomeworkDeletesKey);

  Future<void> addPendingHomeworkDelete(String id) async {
    final ids = getPendingHomeworkDeletes();
    if (!ids.contains(id)) {
      ids.add(id);
      await _saveList(_pendingHomeworkDeletesKey, ids);
    }
  }

  Future<void> removePendingHomeworkDelete(String id) async {
    final ids = getPendingHomeworkDeletes()..remove(id);
    await _saveList(_pendingHomeworkDeletesKey, ids);
  }
}
