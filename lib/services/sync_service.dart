// lib/services/sync_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'local_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // ── Dépendances ────────────────────────────────────────────────────────────
  final LocalService _local = LocalService();
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // ── État ───────────────────────────────────────────────────────────────────
  bool _isOnline = false;
  bool _isSyncing = false;           // évite les syncs parallèles
  StreamSubscription? _connectivitySub;

  /// Stream publique pour que l'UI puisse réagir à l'état de connexion
  final StreamController<bool> _onlineStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get onlineStatus => _onlineStatusController.stream;
  bool get isOnline => _isOnline;
  bool get canUseFirebase => Firebase.apps.isNotEmpty;

  // ══════════════════════════════════════════════════════════════════════════
  //  INITIALISATION — à appeler une seule fois dans main.dart
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    // 1. Vérifier l'état initial de la connexion
    final results = await Connectivity().checkConnectivity();
    _updateOnlineStatus(results);

    // 2. Écouter les changements réseau en temps réel
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final wasOnline = _isOnline;
      _updateOnlineStatus(results);

      if (!wasOnline && _isOnline) {
        syncAll();  // async, ne bloque pas l'UI
      }
    });
  }

  /// Met à jour l'état de connexion et notifie l'UI
  void _updateOnlineStatus(List<ConnectivityResult> results) {
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    _onlineStatusController.add(_isOnline);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SYNCHRONISATION PRINCIPALE
  //  Envoie tous les éléments non synchronisés vers Firebase.
  //  Exécutée en arrière-plan (ne bloque pas l'UI).
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> syncAll() async {
    if (!_isOnline) return;        // pas de connexion, rien à faire
    if (!canUseFirebase) return;   // Firebase non configuré pour cette plateforme
    if (_isSyncing) return;        // sync déjà en cours

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

  // ── Synchronisation des cours ──────────────────────────────────────────────
  Future<void> _syncCourses() async {
    final allCourses = _local.getAllCourses();
    // Filtre : seulement ceux avec synced = false
    final unsyncedCourses = allCourses
        .where((map) => (map['synced'] as bool? ?? false) == false)
        .toList();

    if (unsyncedCourses.isEmpty) return;
    print('[SyncService] ${unsyncedCourses.length} cours à synchroniser');

    for (final courseMap in unsyncedCourses) {
      final id = courseMap['id'] as String;
      final localUpdatedAt = courseMap['updatedAt'] as String?;

      try {
        final docRef = _firestore.collection('courses').doc(id);
        final docSnapshot = await docRef.get();

        // ── Gestion des conflits : last updatedAt wins ─────────────────────
        if (docSnapshot.exists) {
          final remoteUpdatedAt = docSnapshot.data()?['updatedAt'] as String?;
          if (remoteUpdatedAt != null && localUpdatedAt != null) {
            final remoteDate = DateTime.tryParse(remoteUpdatedAt);
            final localDate  = DateTime.tryParse(localUpdatedAt);
            if (remoteDate != null &&
                localDate != null &&
                remoteDate.isAfter(localDate)) {
              // Firebase est plus récent → on met à jour le local avec Firebase
              final remoteData = {
                ...docSnapshot.data()!,
                'id': id,
                'synced': true,
              };
              await _local.saveCourse(remoteData);
              print('[SyncService] Cours $id : version Firebase plus récente → local mis à jour');
              continue;
            }
          }
        }

        // Notre version locale est la plus récente → on envoie vers Firebase
        final dataToUpload = Map<String, dynamic>.from(courseMap)
          ..remove('id')     // pas besoin de stocker l'id dans le document
          ..remove('synced'); // synced est local uniquement

        await docRef.set(dataToUpload, SetOptions(merge: true));

        // Marquer comme synchronisé dans Hive
        await _local.saveCourse({...courseMap, 'synced': true});
        print('[SyncService] Cours $id synchronisé ✓');
      } catch (e) {
        print('[SyncService] Erreur synchronisation cours $id : $e');
      }
    }
  }

  // ── Synchronisation des devoirs ────────────────────────────────────────────
  Future<void> _syncHomeworks() async {
    final allHomeworks = _local.getAllHomeworks();
    final unsyncedHomeworks = allHomeworks
        .where((map) => (map['synced'] as bool? ?? false) == false)
        .toList();

    if (unsyncedHomeworks.isEmpty) return;
    print('[SyncService] ${unsyncedHomeworks.length} devoirs à synchroniser');

    for (final hwMap in unsyncedHomeworks) {
      final id = hwMap['id'] as String;
      final localUpdatedAt = hwMap['updatedAt'] as String?;

      try {
        final docRef = _firestore.collection('homeworks').doc(id);
        final docSnapshot = await docRef.get();

        // Gestion des conflits
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
              print('[SyncService] Devoir $id : version Firebase plus récente → local mis à jour');
              continue;
            }
          }
        }

        final dataToUpload = Map<String, dynamic>.from(hwMap)
          ..remove('id')
          ..remove('synced');

        await docRef.set(dataToUpload, SetOptions(merge: true));
        await _local.saveHomework({...hwMap, 'synced': true});
        print('[SyncService] Devoir $id synchronisé ✓');
      } catch (e) {
        print('[SyncService] Erreur synchronisation devoir $id : $e');
      }
    }
  }

  // ── Traitement des suppressions en attente ─────────────────────────────────
  Future<void> _processPendingDeletes() async {
    // Suppressions de cours
    final courseIdsToDelete = _local.getPendingCourseDeletes();
    for (final id in courseIdsToDelete) {
      try {
        await _firestore.collection('courses').doc(id).delete();
        await _local.removePendingCourseDelete(id);
        print('[SyncService] Cours $id supprimé de Firebase ✓');
      } catch (e) {
        print('[SyncService] Erreur suppression cours $id : $e');
      }
    }

    // Suppressions de devoirs
    final hwIdsToDelete = _local.getPendingHomeworkDeletes();
    for (final id in hwIdsToDelete) {
      try {
        await _firestore.collection('homeworks').doc(id).delete();
        await _local.removePendingHomeworkDelete(id);
        print('[SyncService] Devoir $id supprimé de Firebase ✓');
      } catch (e) {
        print('[SyncService] Erreur suppression devoir $id : $e');
      }
    }
  }

  // ── Nettoyage ──────────────────────────────────────────────────────────────
  void dispose() {
    _connectivitySub?.cancel();
    _onlineStatusController.close();
  }
}
