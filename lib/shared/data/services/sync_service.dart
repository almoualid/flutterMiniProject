import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'local_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final LocalService _local = LocalService();
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  bool _isOnline = false;
  bool _isSyncing = false;
  StreamSubscription? _connectivitySub;

  final StreamController<bool> _onlineStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get onlineStatus => _onlineStatusController.stream;
  bool get isOnline => _isOnline;
  bool get canUseFirebase => Firebase.apps.isNotEmpty;

  Future<void> init() async {
    final results = await Connectivity().checkConnectivity();
    _updateOnlineStatus(results);

    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final wasOnline = _isOnline;
      _updateOnlineStatus(results);

      if (!wasOnline && _isOnline) {
        syncAll();
      }
    });
  }

  void _updateOnlineStatus(List<ConnectivityResult> results) {
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    _onlineStatusController.add(_isOnline);
  }

  Future<void> syncAll() async {
    if (!_isOnline) return;
    if (!canUseFirebase) return;
    if (_isSyncing) return;

    _isSyncing = true;
    print('[SyncService] Démarrage de la synchronisation...');

    try {
      await _syncCourses();
      await _syncHomeworks();
      await _processPendingDeletes();
      print('[SyncService] Synchronisation terminée ✓');
    } catch (e) {
      print('[SyncService] Erreur lors de la synchronisation : $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncCourses() async {
    final allCourses = _local.getAllCourses();
    final unsyncedCourses = allCourses
        .where((map) => (map['synced'] as bool? ?? false) == false)
        .toList();

    if (unsyncedCourses.isEmpty) return;

    for (final courseMap in unsyncedCourses) {
      final id = courseMap['id'] as String;
      final localUpdatedAt = courseMap['updatedAt'] as String?;

      try {
        final docRef = _firestore.collection('courses').doc(id);
        final docSnapshot = await docRef.get();

        if (docSnapshot.exists) {
          final remoteUpdatedAt = docSnapshot.data()?['updatedAt'] as String?;
          if (remoteUpdatedAt != null && localUpdatedAt != null) {
            final remoteDate = DateTime.tryParse(remoteUpdatedAt);
            final localDate  = DateTime.tryParse(localUpdatedAt);
            if (remoteDate != null &&
                localDate != null &&
                remoteDate.isAfter(localDate)) {
              final remoteData = {
                ...docSnapshot.data()!,
                'id': id,
                'synced': true,
              };
              await _local.saveCourse(remoteData);
              continue;
            }
          }
        }

        final dataToUpload = Map<String, dynamic>.from(courseMap)
          ..remove('id')
          ..remove('synced');

        await docRef.set(dataToUpload, SetOptions(merge: true));

        await _local.saveCourse({...courseMap, 'synced': true});
      } catch (e) {
        print('[SyncService] Erreur synchronisation cours $id : $e');
      }
    }
  }

  Future<void> _syncHomeworks() async {
    final allHomeworks = _local.getAllHomeworks();
    final unsyncedHomeworks = allHomeworks
        .where((map) => (map['synced'] as bool? ?? false) == false)
        .toList();

    if (unsyncedHomeworks.isEmpty) return;

    for (final hwMap in unsyncedHomeworks) {
      final id = hwMap['id'] as String;
      final localUpdatedAt = hwMap['updatedAt'] as String?;

      try {
        final docRef = _firestore.collection('homeworks').doc(id);
        final docSnapshot = await docRef.get();

        if (docSnapshot.exists) {
          final remoteUpdatedAt = docSnapshot.data()?['updatedAt'] as String?;
          if (remoteUpdatedAt != null && localUpdatedAt != null) {
            final remoteDate = DateTime.tryParse(remoteUpdatedAt);
            final localDate  = DateTime.tryParse(localUpdatedAt);
            if (remoteDate != null &&
                localDate != null &&
                remoteDate.isAfter(localDate)) {
              final remoteData = {
                ...docSnapshot.data()!,
                'id': id,
                'synced': true,
              };
              await _local.saveHomework(remoteData);
              continue;
            }
          }
        }

        final dataToUpload = Map<String, dynamic>.from(hwMap)
          ..remove('id')
          ..remove('synced');

        await docRef.set(dataToUpload, SetOptions(merge: true));
        await _local.saveHomework({...hwMap, 'synced': true});
      } catch (e) {
        print('[SyncService] Erreur synchronisation devoir $id : $e');
      }
    }
  }

  Future<void> _processPendingDeletes() async {
    final courseIdsToDelete = _local.getPendingCourseDeletes();
    for (final id in courseIdsToDelete) {
      try {
        await _firestore.collection('courses').doc(id).delete();
        await _local.removePendingCourseDelete(id);
      } catch (e) {
        print('[SyncService] Erreur suppression cours $id : $e');
      }
    }

    final hwIdsToDelete = _local.getPendingHomeworkDeletes();
    for (final id in hwIdsToDelete) {
      try {
        await _firestore.collection('homeworks').doc(id).delete();
        await _local.removePendingHomeworkDelete(id);
      } catch (e) {
        print('[SyncService] Erreur suppression devoir $id : $e');
      }
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _onlineStatusController.close();
  }
}
