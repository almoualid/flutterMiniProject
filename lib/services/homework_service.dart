// lib/services/homework_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:student_academic_manager/exceptions/app_exception.dart';
import 'package:student_academic_manager/models/homework.dart';

class HomeworkService {
  static final HomeworkService _instance = HomeworkService._internal();

  late final FirebaseFirestore _firestore;
  late final CollectionReference<Map<String, dynamic>> _homeworksCollection;

  factory HomeworkService() {
    return _instance;
  }

  HomeworkService._internal() {
    _firestore = FirebaseFirestore.instance;
    _homeworksCollection = _firestore.collection('homeworks');
  }

  /// Get all homeworks as a real-time stream
  /// Returns a stream of homework lists that updates whenever the collection changes
  Stream<List<Homework>> getAll() {
    try {
      return _homeworksCollection.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => Homework.fromMap(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      throw AppException(
        message: 'Failed to fetch homeworks',
        code: 'FETCH_HOMEWORKS_ERROR',
        originalError: e,
      );
    }
  }

  /// Get a single homework by ID
  /// Returns null if the homework does not exist
  Future<Homework?> getById(String id) async {
    try {
      final doc = await _homeworksCollection.doc(id).get();
      if (!doc.exists) {
        return null;
      }
      return Homework.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      throw AppException(
        message: 'Failed to fetch homework with ID: $id',
        code: 'FETCH_HOMEWORK_BY_ID_ERROR',
        originalError: e,
      );
    }
  }

  /// Add a new homework
  /// Auto-generates a document ID if the homework doesn't have one
  /// Returns the ID of the created document
  Future<String> add(Homework homework) async {
    try {
      final now = DateTime.now();
      final docRef = await _homeworksCollection.add({
        ...homework.toMap(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      return docRef.id;
    } catch (e) {
      throw AppException(
        message: 'Failed to add homework: ${homework.title}',
        code: 'ADD_HOMEWORK_ERROR',
        originalError: e,
      );
    }
  }

  /// Update an existing homework
  /// Requires the homework to have a valid ID
  Future<void> update(Homework homework) async {
    try {
      if (homework.id.isEmpty) {
        throw AppException(
          message: 'Cannot update homework without an ID',
          code: 'INVALID_HOMEWORK_ID',
        );
      }

      final now = DateTime.now();
      await _homeworksCollection.doc(homework.id).update({
        ...homework.toMap(),
        'updatedAt': now.toIso8601String(),
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Failed to update homework with ID: ${homework.id}',
        code: 'UPDATE_HOMEWORK_ERROR',
        originalError: e,
      );
    }
  }

  /// Delete a homework by ID
  Future<void> delete(String id) async {
    try {
      if (id.isEmpty) {
        throw AppException(
          message: 'Cannot delete homework with empty ID',
          code: 'INVALID_HOMEWORK_ID',
        );
      }

      await _homeworksCollection.doc(id).delete();
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Failed to delete homework with ID: $id',
        code: 'DELETE_HOMEWORK_ERROR',
        originalError: e,
      );
    }
  }

  /// Get homeworks for a specific course (filtered by courseId)
  /// Returns a real-time stream of homeworks for the given course
  Stream<List<Homework>> getHomeworksByCourse(String courseId) {
    try {
      if (courseId.isEmpty) {
        throw AppException(
          message: 'Cannot fetch homeworks with empty courseId',
          code: 'INVALID_COURSE_ID',
        );
      }

      return _homeworksCollection
          .where('courseId', isEqualTo: courseId)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => Homework.fromMap(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Failed to fetch homeworks for course: $courseId',
        code: 'FETCH_HOMEWORKS_BY_COURSE_ERROR',
        originalError: e,
      );
    }
  }

  /// Get pending homeworks (not done and deadline hasn't passed)
  Stream<List<Homework>> getPendingHomeworks() {
    try {
      final now = DateTime.now();
      return _homeworksCollection
          .where('isDone', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
        final allHomeworks = snapshot.docs
            .map((doc) => Homework.fromMap(doc.data(), doc.id))
            .toList();
        
        // Filter in Dart since Firestore has limitations with multiple where clauses
        return allHomeworks
            .where((hw) => hw.deadline.isAfter(now))
            .toList();
      });
    } catch (e) {
      throw AppException(
        message: 'Failed to fetch pending homeworks',
        code: 'FETCH_PENDING_HOMEWORKS_ERROR',
        originalError: e,
      );
    }
  }

  /// Get overdue homeworks (not done and deadline has passed)
  Stream<List<Homework>> getOverdueHomeworks() {
    try {
      final now = DateTime.now();
      return _homeworksCollection
          .where('isDone', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
        final allHomeworks = snapshot.docs
            .map((doc) => Homework.fromMap(doc.data(), doc.id))
            .toList();
        
        // Filter in Dart since Firestore has limitations with multiple where clauses
        return allHomeworks
            .where((hw) => hw.deadline.isBefore(now))
            .toList();
      });
    } catch (e) {
      throw AppException(
        message: 'Failed to fetch overdue homeworks',
        code: 'FETCH_OVERDUE_HOMEWORKS_ERROR',
        originalError: e,
      );
    }
  }

  /// Get completed homeworks
  Stream<List<Homework>> getCompletedHomeworks() {
    try {
      return _homeworksCollection
          .where('isDone', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => Homework.fromMap(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      throw AppException(
        message: 'Failed to fetch completed homeworks',
        code: 'FETCH_COMPLETED_HOMEWORKS_ERROR',
        originalError: e,
      );
    }
  }

  /// Toggle homework completion status
  Future<void> toggleStatus(String id, bool isDone) async {
    try {
      if (id.isEmpty) {
        throw AppException(
          message: 'Cannot toggle status of homework with empty ID',
          code: 'INVALID_HOMEWORK_ID',
        );
      }

      final now = DateTime.now();
      await _homeworksCollection.doc(id).update({
        'isDone': isDone,
        'updatedAt': now.toIso8601String(),
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Failed to toggle homework status for ID: $id',
        code: 'TOGGLE_HOMEWORK_STATUS_ERROR',
        originalError: e,
      );
    }
  }

  /// Get pending homeworks for a specific course
  Stream<List<Homework>> getPendingHomeworksByCourse(String courseId) {
    try {
      if (courseId.isEmpty) {
        throw AppException(
          message: 'Cannot fetch homeworks with empty courseId',
          code: 'INVALID_COURSE_ID',
        );
      }

      final now = DateTime.now();
      return _homeworksCollection
          .where('courseId', isEqualTo: courseId)
          .where('isDone', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
        final allHomeworks = snapshot.docs
            .map((doc) => Homework.fromMap(doc.data(), doc.id))
            .toList();
        
        return allHomeworks
            .where((hw) => hw.deadline.isAfter(now))
            .toList();
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Failed to fetch pending homeworks for course: $courseId',
        code: 'FETCH_PENDING_HOMEWORKS_BY_COURSE_ERROR',
        originalError: e,
      );
    }
  }
}
