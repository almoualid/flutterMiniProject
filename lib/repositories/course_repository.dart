// lib/repositories/course_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORY COURS
//
// C'est LA couche centrale de l'architecture offline-first.
// L'UI ne parle JAMAIS directement à Firestore — elle passe TOUJOURS ici.
//
// Schéma de fonctionnement :
//
//   UI → CourseRepository → LocalService (Hive) ← lecture TOUJOURS
//                        → SyncService          → Firebase (si online)
//
// Règles :
//   • getAll()  : lit depuis Hive. Si Hive vide → fetch Firebase → sauvegarde Hive
//   • add()     : génère UUID local → sauvegarde Hive (synced=false) → essaye Firebase
//   • update()  : met à jour Hive (synced=false) → essaye Firebase
//   • delete()  : supprime de Hive → essaye Firebase (sinon : pending delete)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:student_academic_manager/models/course.dart';
import 'package:student_academic_manager/repositories/homework_repository.dart';
import 'package:student_academic_manager/exceptions/app_exception.dart';
import 'package:student_academic_manager/services/local_service.dart';
import 'package:student_academic_manager/services/sync_service.dart';

class CourseRepository {
  static final CourseRepository _instance = CourseRepository._internal();
  factory CourseRepository() => _instance;
  CourseRepository._internal();

  final LocalService _local = LocalService();
  final SyncService _sync = SyncService();
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();
  final HomeworkRepository _homeworkRepository = HomeworkRepository();

  // ══════════════════════════════════════════════════════════════════════════
  //  getAll() — STREAM depuis Hive
  //  L'UI reçoit les mises à jour automatiquement via Hive box.watch()
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<Course>> getAll() async* {
    // ── Étape 1 : Premier lancement → si Hive vide, récupérer Firebase ────
    if (_local.isCoursesEmpty && _sync.canUseFirebase) {
      try {
        print('[CourseRepository] Hive vide → fetch Firebase...');
        final snapshot = await _firestore.collection('courses').get();
        final courses = snapshot.docs
            .map((doc) => Course.fromMap(doc.data(), doc.id))
            .toList();

        // Sauvegarder en local avec synced = true (données venant de Firebase)
        for (final c in courses) {
          await _local.saveCourse({...c.toLocalMap(), 'synced': true});
        }
        print(
          '[CourseRepository] ${courses.length} cours chargés depuis Firebase et sauvegardés localement',
        );
      } catch (e) {
        // Offline ou erreur Firebase → on continue avec Hive vide
        print('[CourseRepository] Impossible de contacter Firebase : $e');
      }
    }

    // ── Étape 2 : Émettre les données locales actuelles ────────────────────
    yield _getCoursesFromLocal();

    // ── Étape 3 : Écouter les changements dans la box Hive ────────────────
    // Chaque fois qu'un cours est ajouté/modifié/supprimé localement,
    // Hive émet un BoxEvent → on ré-émet la liste complète
    await for (final _ in _local.coursesBox.watch()) {
      yield _getCoursesFromLocal();
    }
  }

  /// Convertit les maps Hive en objets Course
  List<Course> _getCoursesFromLocal() {
    return _local
        .getAllCourses()
        .map((map) => Course.fromLocalMap(map))
        .toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  getById() — lecture depuis Hive uniquement
  // ══════════════════════════════════════════════════════════════════════════

  Future<Course?> getById(String id) async {
    final map = _local.getCourseById(id);
    if (map == null) return null;
    return Course.fromLocalMap(map);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  add() — écriture locale d'abord, puis Firebase si online
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> add(Course course) async {
    try {
      final now = DateTime.now();

      // 1. Générer un ID unique (UUID v4)
      final String id = _uuid.v4();

      // 2. Créer le cours avec les timestamps
      final courseWithMeta = course.copyWith(
        id: id,
        createdAt: now,
        updatedAt: now,
        synced: false, // pas encore synchronisé
      );

      // 3. Sauvegarder dans Hive EN PREMIER (offline-first)
      await _local.saveCourse(courseWithMeta.toLocalMap());
      print(
        '[CourseRepository] Cours "${course.name}" sauvegardé localement (id: $id)',
      );

      // 4. Si online → envoyer vers Firebase immédiatement
      if (_sync.isOnline && _sync.canUseFirebase) {
        try {
          await _firestore
              .collection('courses')
              .doc(id)
              .set(courseWithMeta.toMap()); // toMap() exclut synced

          // Marquer comme synchronisé dans Hive
          await _local.saveCourse({
            ...courseWithMeta.toLocalMap(),
            'synced': true,
          });
          print(
            '[CourseRepository] Cours "${course.name}" synchronisé avec Firebase ✓',
          );
        } catch (e) {
          // Firebase a échoué → reste avec synced=false, sera sync plus tard
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

  // ══════════════════════════════════════════════════════════════════════════
  //  update() — mise à jour locale puis Firebase si online
  // ══════════════════════════════════════════════════════════════════════════

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
        synced: false, // modification en attente de sync
      );

      // 1. Mise à jour dans Hive
      await _local.saveCourse(updatedCourse.toLocalMap());
      print('[CourseRepository] Cours "${course.name}" mis à jour localement');

      // 2. Si online → envoyer vers Firebase
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

  // ══════════════════════════════════════════════════════════════════════════
  //  delete() — suppression locale immédiate + suppression des devoirs liés
  //  Si offline → on mémorise l'ID dans pending deletes
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> delete(String id) async {
    try {
      if (id.isEmpty) {
        throw AppException(
          message: 'ID du cours manquant pour la suppression',
          code: 'INVALID_COURSE_ID',
        );
      }

      // 0. Supprimer d'abord les devoirs liés à ce cours
      await _homeworkRepository.deleteByCourseId(id);
      print('[CourseRepository] Devoirs associés au cours $id supprimés');

      // 1. Supprimer de Hive immédiatement
      await _local.deleteCourse(id);
      print('[CourseRepository] Cours $id supprimé localement');

      // 2. Si online → supprimer de Firebase
      if (_sync.isOnline && _sync.canUseFirebase) {
        try {
          await _firestore.collection('courses').doc(id).delete();
          print('[CourseRepository] Cours $id supprimé de Firebase ✓');
        } catch (e) {
          // Firebase inaccessible → mémoriser pour suppression ultérieure
          await _local.addPendingCourseDelete(id);
          print(
            '[CourseRepository] Suppression Firebase reportée pour cours $id',
          );
        }
      } else {
        // Offline → mémoriser la suppression
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
