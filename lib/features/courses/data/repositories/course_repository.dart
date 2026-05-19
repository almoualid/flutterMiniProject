import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:student_companion/features/courses/data/models/course.dart';
import 'package:student_companion/features/homework/data/repositories/homework_repository.dart';
import 'package:student_companion/exceptions/app_exception.dart';
import 'package:student_companion/shared/data/services/local_service.dart';
import 'package:student_companion/shared/data/services/sync_service.dart';

class CourseRepository {
  static final CourseRepository _instance = CourseRepository._internal();
  factory CourseRepository() => _instance;
  CourseRepository._internal();

  final LocalService _local = LocalService();
  final SyncService _sync = SyncService();
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();
  final HomeworkRepository _homeworkRepository = HomeworkRepository();

  Stream<List<Course>> getAll() async* {
    if (_local.isCoursesEmpty && _sync.canUseFirebase) {
      try {
        print('[CourseRepository] Hive vide → fetch Firebase...');
        final snapshot = await _firestore.collection('courses').get();
        final courses = snapshot.docs
            .map((doc) => Course.fromMap(doc.data(), doc.id))
            .toList();

        for (final c in courses) {
          await _local.saveCourse({...c.toLocalMap(), 'synced': true});
        }
        print(
          '[CourseRepository] ${courses.length} cours chargés depuis Firebase et sauvegardés localement',
        );
      } catch (e) {
        print('[CourseRepository] Impossible de contacter Firebase : $e');
      }
    }

    yield _getCoursesFromLocal();

    await for (final _ in _local.coursesBox.watch()) {
      yield _getCoursesFromLocal();
    }
  }

  List<Course> _getCoursesFromLocal() {
    return _local
        .getAllCourses()
        .map((map) => Course.fromLocalMap(map))
        .toList();
  }

  Future<Course?> getById(String id) async {
    final map = _local.getCourseById(id);
    if (map == null) return null;
    return Course.fromLocalMap(map);
  }

  Future<String> add(Course course) async {
    try {
      final now = DateTime.now();
      final String id = _uuid.v4();

      final courseWithMeta = course.copyWith(
        id: id,
        createdAt: now,
        updatedAt: now,
        synced: false,
      );

      await _local.saveCourse(courseWithMeta.toLocalMap());
      print(
        '[CourseRepository] Cours "${course.name}" sauvegardé localement (id: $id)',
      );

      if (_sync.isOnline && _sync.canUseFirebase) {
        try {
          await _firestore
              .collection('courses')
              .doc(id)
              .set(courseWithMeta.toMap()); 

          await _local.saveCourse({
            ...courseWithMeta.toLocalMap(),
            'synced': true,
          });
          print(
            '[CourseRepository] Cours "${course.name}" synchronisé avec Firebase ✓',
          );
        } catch (e) {
          print('[CourseRepository] Firebase inaccessible, sync reporté : $e');
        }
      }

      return id;
    } catch (e) {
      throw AppException(
        message: 'Impossible d\'ajouter le cours : ${course.name}',
        code: 'ADD_COURSE_ERROR',
        originalError: e,
      );
    }
  }

  Future<void> update(Course course) async {
    try {
      if (course.id.isEmpty) {
        throw AppException(
          message: 'ID du cours manquant pour la mise à jour',
          code: 'INVALID_COURSE_ID',
        );
      }

      final now = DateTime.now();
      final updatedCourse = course.copyWith(
        updatedAt: now,
        synced: false,
      );

      await _local.saveCourse(updatedCourse.toLocalMap());
      print('[CourseRepository] Cours "${course.name}" mis à jour localement');

      if (_sync.isOnline && _sync.canUseFirebase) {
        try {
          await _firestore
              .collection('courses')
              .doc(course.id)
              .update(updatedCourse.toMap());

          await _local.saveCourse({
            ...updatedCourse.toLocalMap(),
            'synced': true,
          });
          print('[CourseRepository] Cours "${course.name}" synchronisé ✓');
        } catch (e) {
          print('[CourseRepository] Firebase inaccessible, sync reporté : $e');
        }
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(
        message: 'Impossible de mettre à jour le cours',
        code: 'UPDATE_COURSE_ERROR',
        originalError: e,
      );
    }
  }

  Future<void> delete(String id) async {
    try {
      if (id.isEmpty) {
        throw AppException(
          message: 'ID du cours manquant pour la suppression',
          code: 'INVALID_COURSE_ID',
        );
      }

      await _homeworkRepository.deleteByCourseId(id);
      print('[CourseRepository] Devoirs associés au cours $id supprimés');

      await _local.deleteCourse(id);
      print('[CourseRepository] Cours $id supprimé localement');

      if (_sync.isOnline && _sync.canUseFirebase) {
        try {
          await _firestore.collection('courses').doc(id).delete();
          print('[CourseRepository] Cours $id supprimé de Firebase ✓');
        } catch (e) {
          await _local.addPendingCourseDelete(id);
          print(
            '[CourseRepository] Suppression Firebase reportée pour cours $id',
          );
        }
      } else {
        await _local.addPendingCourseDelete(id);
        print(
          '[CourseRepository] Offline : suppression Firebase de cours $id reportée',
        );
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(
        message: 'Impossible de supprimer le cours',
        code: 'DELETE_COURSE_ERROR',
        originalError: e,
      );
    }
  }
}
