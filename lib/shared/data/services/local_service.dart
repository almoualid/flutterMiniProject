import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class LocalService {
  static final LocalService _instance = LocalService._internal();
  factory LocalService() => _instance;
  LocalService._internal();

  static const String coursesBoxName    = 'courses_box';
  static const String homeworksBoxName  = 'homeworks_box';
  
  static const String metaBoxName       = 'meta_box';

  static const String _pendingCourseDeletesKey   = 'pending_course_deletes';
  static const String _pendingHomeworkDeletesKey = 'pending_homework_deletes';

  Box<String> get coursesBox   => Hive.box<String>(coursesBoxName);
  Box<String> get homeworksBox => Hive.box<String>(homeworksBoxName);
  Box<String> get metaBox      => Hive.box<String>(metaBoxName);

  List<Map<String, dynamic>> getAllCourses() {
    return coursesBox.values
        .map((jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>)
        .toList();
  }

  Map<String, dynamic>? getCourseById(String id) {
    final jsonStr = coursesBox.get(id);
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  Future<void> saveCourse(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    await coursesBox.put(id, jsonEncode(data));
  }

  Future<void> saveCoursesBatch(List<Map<String, dynamic>> courses) async {
    for (final course in courses) {
      await saveCourse(course);
    }
  }

  Future<void> deleteCourse(String id) async {
    await coursesBox.delete(id);
  }

  bool get isCoursesEmpty => coursesBox.isEmpty;

  List<Map<String, dynamic>> getAllHomeworks() {
    return homeworksBox.values
        .map((jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>)
        .toList();
  }

  Map<String, dynamic>? getHomeworkById(String id) {
    final jsonStr = homeworksBox.get(id);
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  Future<void> saveHomework(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    await homeworksBox.put(id, jsonEncode(data));
  }

  Future<void> saveHomeworksBatch(List<Map<String, dynamic>> homeworks) async {
    for (final hw in homeworks) {
      await saveHomework(hw);
    }
  }

  Future<void> deleteHomework(String id) async {
    await homeworksBox.delete(id);
  }

  bool get isHomeworksEmpty => homeworksBox.isEmpty;

  List<String> _loadList(String key) {
    final jsonStr = metaBox.get(key);
    if (jsonStr == null) return [];
    return (jsonDecode(jsonStr) as List).cast<String>();
  }

  Future<void> _saveList(String key, List<String> ids) async {
    await metaBox.put(key, jsonEncode(ids));
  }

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
