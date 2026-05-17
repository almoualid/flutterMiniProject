// lib/services/course_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:student_academic_manager/exceptions/app_exception.dart';
import 'package:student_academic_manager/models/course.dart';

class CourseService {
  static final CourseService _instance = CourseService._internal();

  late final FirebaseFirestore _firestore;
  late final CollectionReference<Map<String, dynamic>> _coursesCollection;

  factory CourseService() {
    return _instance;
  }

  CourseService._internal() {
    _firestore = FirebaseFirestore.instance;
    _coursesCollection = _firestore.collection('courses');
  }

  /// Get all courses as a real-time stream
  /// Returns a stream of course lists that updates whenever the collection changes
  Stream<List<Course>> getAll() {
    try {
      return _coursesCollection.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => Course.fromMap(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      throw AppException(
        message: 'Failed to fetch courses',
        code: 'FETCH_COURSES_ERROR',
        originalError: e,
      );
    }
  }

  /// Get a single course by ID
  /// Returns null if the course does not exist
  Future<Course?> getById(String id) async {
    try {
      final doc = await _coursesCollection.doc(id).get();
      if (!doc.exists) {
        return null;
      }
      return Course.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      throw AppException(
        message: 'Failed to fetch course with ID: $id',
        code: 'FETCH_COURSE_BY_ID_ERROR',
        originalError: e,
      );
    }
  }

  /// Add a new course
  /// Auto-generates a document ID if the course doesn't have one
  /// Returns the ID of the created document
  Future<String> add(Course course) async {
    try {
      final now = DateTime.now();
      final docRef = await _coursesCollection.add({
        ...course.toMap(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      return docRef.id;
    } catch (e) {
      throw AppException(
        message: 'Failed to add course: ${course.name}',
        code: 'ADD_COURSE_ERROR',
        originalError: e,
      );
    }
  }

  /// Update an existing course
  /// Requires the course to have a valid ID
  Future<void> update(Course course) async {
    try {
      if (course.id.isEmpty) {
        throw AppException(
          message: 'Cannot update course without an ID',
          code: 'INVALID_COURSE_ID',
        );
      }

      final now = DateTime.now();
      await _coursesCollection.doc(course.id).update({
        ...course.toMap(),
        'updatedAt': now.toIso8601String(),
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Failed to update course with ID: ${course.id}',
        code: 'UPDATE_COURSE_ERROR',
        originalError: e,
      );
    }
  }

  /// Delete a course by ID
  Future<void> delete(String id) async {
    try {
      if (id.isEmpty) {
        throw AppException(
          message: 'Cannot delete course with empty ID',
          code: 'INVALID_COURSE_ID',
        );
      }

      await _coursesCollection.doc(id).delete();
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Failed to delete course with ID: $id',
        code: 'DELETE_COURSE_ERROR',
        originalError: e,
      );
    }
  }

  /// Search courses by teacher name (case-insensitive)
  Stream<List<Course>> searchByTeacher(String teacherName) {
    try {
      return getAll().map((courses) {
        return courses
            .where((course) =>
                course.teacher.toLowerCase().contains(teacherName.toLowerCase()))
            .toList();
      });
    } catch (e) {
      throw AppException(
        message: 'Failed to search courses by teacher: $teacherName',
        code: 'SEARCH_BY_TEACHER_ERROR',
        originalError: e,
      );
    }
  }

  /// Get courses for a specific day
  Stream<List<Course>> getCoursesByDay(String day) {
    try {
      return _coursesCollection
          .where('day', isEqualTo: day)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => Course.fromMap(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      throw AppException(
        message: 'Failed to fetch courses for day: $day',
        code: 'FETCH_COURSES_BY_DAY_ERROR',
        originalError: e,
      );
    }
  }
}
