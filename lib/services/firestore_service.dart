// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:student_academic_manager/models/course.dart';
import 'package:student_academic_manager/models/homework.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Collection references
  CollectionReference<Map<String, dynamic>> get coursesCollection =>
      _firestore.collection('courses');
  CollectionReference<Map<String, dynamic>> get homeworksCollection =>
      _firestore.collection('homeworks');

  factory FirestoreService() {
    return _instance;
  }

  FirestoreService._internal();

  // ============ COURSE OPERATIONS ============

  /// Get all courses
  Stream<List<Course>> getAllCourses() {
    return coursesCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Course.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get a single course by ID
  Future<Course?> getCourseById(String courseId) async {
    try {
      final doc = await coursesCollection.doc(courseId).get();
      if (doc.exists) {
        return Course.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new course
  Future<String> createCourse(Course course) async {
    try {
      final docRef = await coursesCollection.add({
        ...course.toMap(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing course
  Future<void> updateCourse(String courseId, Course course) async {
    try {
      await coursesCollection.doc(courseId).update({
        ...course.toMap(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a course
  Future<void> deleteCourse(String courseId) async {
    try {
      await coursesCollection.doc(courseId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // ============ HOMEWORK OPERATIONS ============

  /// Get all homeworks
  Stream<List<Homework>> getAllHomeworks() {
    return homeworksCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Homework.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get homeworks for a specific course
  Stream<List<Homework>> getHomeworksByCourse(String courseId) {
    return homeworksCollection
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Homework.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Get a single homework by ID
  Future<Homework?> getHomeworkById(String homeworkId) async {
    try {
      final doc = await homeworksCollection.doc(homeworkId).get();
      if (doc.exists) {
        return Homework.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new homework
  Future<String> createHomework(Homework homework) async {
    try {
      final docRef = await homeworksCollection.add({
        ...homework.toMap(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing homework
  Future<void> updateHomework(String homeworkId, Homework homework) async {
    try {
      await homeworksCollection.doc(homeworkId).update({
        ...homework.toMap(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Mark homework as done/undone
  Future<void> toggleHomeworkStatus(String homeworkId, bool isDone) async {
    try {
      await homeworksCollection.doc(homeworkId).update({
        'isDone': isDone,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a homework
  Future<void> deleteHomework(String homeworkId) async {
    try {
      await homeworksCollection.doc(homeworkId).delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Get pending homeworks (not done and deadline hasn't passed)
  Stream<List<Homework>> getPendingHomeworks() {
    final now = DateTime.now();
    return homeworksCollection
        .where('isDone', isEqualTo: false)
        .where('deadline', isGreaterThan: now.toIso8601String())
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Homework.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Get overdue homeworks (not done and deadline has passed)
  Stream<List<Homework>> getOverdueHomeworks() {
    final now = DateTime.now();
    return homeworksCollection
        .where('isDone', isEqualTo: false)
        .where('deadline', isLessThan: now.toIso8601String())
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Homework.fromMap(doc.data(), doc.id))
              .toList();
        });
  }
}
