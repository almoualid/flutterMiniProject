import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:student_companion/features/homework/data/models/homework.dart';
import 'package:student_companion/exceptions/app_exception.dart';
import 'package:student_companion/shared/data/services/local_service.dart';
import 'package:student_companion/shared/data/services/sync_service.dart';
import 'package:student_companion/shared/utils/notification_helper.dart';

class HomeworkRepository {
  static final HomeworkRepository _instance = HomeworkRepository._internal();
  factory HomeworkRepository() => _instance;
  HomeworkRepository._internal();

  final LocalService _local = LocalService();
  final SyncService _sync = SyncService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  Stream<List<Homework>> getAll() async* {
    if (_local.isHomeworksEmpty && _sync.canUseFirebase) {
      try {
        final snapshot = await _firestore.collection('homeworks').get();
        final homeworks = snapshot.docs
            .map((doc) => Homework.fromMap(doc.data(), doc.id))
            .toList();

        for (final hw in homeworks) {
          await _local.saveHomework({...hw.toLocalMap(), 'synced': true});
        }
        print(
          '[HomeworkRepository] ${homeworks.length} devoirs chargés depuis Firebase',
        );
      } catch (e) {
        print('[HomeworkRepository] Firebase inaccessible : $e');
      }
    }

    yield _getHomeworksFromLocal();

    await for (final _ in _local.homeworksBox.watch()) {
      yield _getHomeworksFromLocal();
    }
  }

  List<Homework> _getHomeworksFromLocal() {
    return _local
        .getAllHomeworks()
        .map((map) => Homework.fromLocalMap(map))
        .toList();
  }

  Future<Homework?> getById(String id) async {
    final map = _local.getHomeworkById(id);
    if (map == null) return null;
    return Homework.fromLocalMap(map);
  }

  Future<String> add(Homework homework) async {
    try {
      final now = DateTime.now();
      final String id = _uuid.v4();

      final hwWithMeta = homework.copyWith(
        id: id,
        createdAt: now,
        updatedAt: now,
        synced: false,
      );

      await _local.saveHomework(hwWithMeta.toLocalMap());
      print(
        '[HomeworkRepository] Devoir "${homework.title}" sauvegardé localement',
      );

      if (_sync.isOnline && _sync.canUseFirebase) {
        try {
          await _firestore
              .collection('homeworks')
              .doc(id)
              .set(hwWithMeta.toMap());
          await _local.saveHomework({
            ...hwWithMeta.toLocalMap(),
            'synced': true,
          });
          print(
            '[HomeworkRepository] Devoir "${homework.title}" synchronisé ✓',
          );
        } catch (e) {
          print(
            '[HomeworkRepository] Firebase inaccessible, sync reporté : $e',
          );
        }
      }

      await NotificationHelper.scheduleOrShowReminder(hwWithMeta);

      return id;
    } catch (e) {
      throw AppException(
        message: 'Impossible d\'ajouter le devoir : ${homework.title}',
        code: 'ADD_HOMEWORK_ERROR',
        originalError: e,
      );
    }
  }

  Future<void> update(Homework homework) async {
    try {
      if (homework.id.isEmpty) {
        throw AppException(
          message: 'ID du devoir manquant',
          code: 'INVALID_HOMEWORK_ID',
        );
      }

      final now = DateTime.now();
      final updated = homework.copyWith(updatedAt: now, synced: false);

      await _local.saveHomework(updated.toLocalMap());
      print(
        '[HomeworkRepository] Devoir "${homework.title}" mis à jour localement',
      );

      if (_sync.isOnline && _sync.canUseFirebase) {
        try {
          await _firestore
              .collection('homeworks')
              .doc(homework.id)
              .update(updated.toMap());
          await _local.saveHomework({...updated.toLocalMap(), 'synced': true});
          print(
            '[HomeworkRepository] Devoir "${homework.title}" synchronisé ✓',
          );
        } catch (e) {
          print(
            '[HomeworkRepository] Firebase inaccessible, sync reporté : $e',
          );
        }
      }

      await NotificationHelper.rescheduleReminder(updated);

    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(
        message: 'Impossible de mettre à jour le devoir',
        code: 'UPDATE_HOMEWORK_ERROR',
        originalError: e,
      );
    }
  }

  Future<void> toggleStatus(String id, bool isDone) async {
    final map = _local.getHomeworkById(id);
    if (map == null) {
      throw AppException(
        message: 'Devoir introuvable en local',
        code: 'HOMEWORK_NOT_FOUND',
      );
    }

    final hw = Homework.fromLocalMap(map);
    await update(hw.copyWith(isDone: isDone));
  }

  Future<void> delete(String id) async {
    try {
      if (id.isEmpty) {
        throw AppException(
          message: 'ID du devoir manquant',
          code: 'INVALID_HOMEWORK_ID',
        );
      }

      await NotificationHelper.cancelReminder(id);

      await _local.deleteHomework(id);
      print('[HomeworkRepository] Devoir $id supprimé localement');

      if (_sync.isOnline && _sync.canUseFirebase) {
        try {
          await _firestore.collection('homeworks').doc(id).delete();
          print('[HomeworkRepository] Devoir $id supprimé de Firebase ✓');
        } catch (e) {
          await _local.addPendingHomeworkDelete(id);
          print(
            '[HomeworkRepository] Suppression Firebase reportée pour devoir $id',
          );
        }
      } else {
        await _local.addPendingHomeworkDelete(id);
        print(
          '[HomeworkRepository] Offline : suppression Firebase devoir $id reportée',
        );
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(
        message: 'Impossible de supprimer le devoir',
        code: 'DELETE_HOMEWORK_ERROR',
        originalError: e,
      );
    }
  }

  List<Homework> getHomeworksByCourseId(String courseId) {
    return _getHomeworksFromLocal()
        .where((hw) => hw.courseId == courseId)
        .toList();
  }

  Future<void> deleteByCourseId(String courseId) async {
    try {
      final homeworks = getHomeworksByCourseId(courseId);

      for (final hw in homeworks) {
        await NotificationHelper.cancelReminder(hw.id);

        await _local.deleteHomework(hw.id);
        print(
          '[HomeworkRepository] Devoir ${hw.id} (cours $courseId) supprimé localement',
        );

        if (_sync.isOnline && _sync.canUseFirebase) {
          try {
            await _firestore.collection('homeworks').doc(hw.id).delete();
            print(
              '[HomeworkRepository] Devoir ${hw.id} supprimé de Firebase ✓',
            );
          } catch (e) {
            await _local.addPendingHomeworkDelete(hw.id);
            print(
              '[HomeworkRepository] Suppression Firebase reportée pour devoir ${hw.id}',
            );
          }
        } else {
          await _local.addPendingHomeworkDelete(hw.id);
          print(
            '[HomeworkRepository] Offline : suppression Firebase devoir ${hw.id} reportée',
          );
        }
      }
    } catch (e) {
      throw AppException(
        message: 'Impossible de supprimer les devoirs du cours',
        code: 'DELETE_HOMEWORKS_BY_COURSE_ERROR',
        originalError: e,
      );
    }
  }
}
