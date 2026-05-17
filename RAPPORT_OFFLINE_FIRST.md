# Rapport Technique — Tâche 4 : Mode Offline + Synchronisation Firebase

---

## 1. Concept Offline-First

L'approche **offline-first** signifie que l'application est conçue pour fonctionner **d'abord sans internet**, puis se synchroniser quand la connexion est disponible. Contrairement à l'approche "online-first" où l'absence de réseau bloque l'utilisateur, l'offline-first traite le réseau comme une amélioration optionnelle.

### Problème résolu
Dans la version originale du projet, toutes les opérations CRUD passaient directement par Firebase Firestore. Dès qu'internet était coupé, l'application devenait inutilisable : impossible d'ajouter, modifier, ou consulter des cours et des devoirs.

### Principe de base
> "Écrire d'abord localement, synchroniser ensuite avec le cloud."

---

## 2. Architecture Mise en Place

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERFACE (UI)                           │
│           CourseListScreen / HomeworkListScreen / Forms          │
└────────────────────────┬────────────────────────────────────────┘
                         │  StreamBuilder (écoute les changements)
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                       REPOSITORIES                               │
│          CourseRepository  /  HomeworkRepository                 │
│  • Orchestre Local et Remote                                     │
│  • L'UI n'accède JAMAIS directement à Firebase                   │
└───────────┬──────────────────────────────────┬──────────────────┘
            │                                  │
            ▼                                  ▼
┌───────────────────────┐          ┌───────────────────────────┐
│    LOCAL (Hive)       │          │  FIREBASE (Cloud)         │
│    LocalService       │          │  Firestore via SDK        │
│  • courses_box        │◄─────────│  (sync si online)         │
│  • homeworks_box      │          └──────────────┬────────────┘
│  • meta_box           │                         │
└───────────────────────┘                         │
            ▲                                     │
            │                                     │
┌───────────────────────────────────────────────────────────────┐
│                        SyncService                             │
│  • connectivity_plus : détecte retour réseau                  │
│  • syncAll() : envoie les éléments avec synced=false          │
│  • processPendingDeletes() : supprime sur Firebase            │
│  • Gestion conflits : last updatedAt wins                     │
└───────────────────────────────────────────────────────────────┘
```

### Flux d'un appel CRUD (ex : ajout d'un cours)

```
Utilisateur appuie sur "Ajouter"
    ↓
CourseFormScreen._saveCourse()
    ↓
CourseRepository.add(course)
    ↓
① Génère un UUID local (id unique)
② Sauvegarde dans Hive avec synced=false  ← IMMÉDIAT
③ Si online → envoie à Firebase + marque synced=true
   Si offline → reste synced=false (sera sync plus tard)
    ↓
Hive émet un BoxEvent
    ↓
Stream dans CourseRepository.getAll() émet la nouvelle liste
    ↓
StreamBuilder reconstruit l'UI → le cours apparaît IMMÉDIATEMENT
```

---

## 3. Fonctionnement du Premier Chargement (local vide)

Lors du premier lancement de l'application (ou après une réinstallation), le stockage Hive est vide. Voici ce qui se passe dans `CourseRepository.getAll()` :

```
getAll() est appelé par CourseListScreen
    ↓
Vérifie : isCoursesEmpty → true
    ↓
Tente Firebase.collection('courses').get()
    ↓
Si succès (online) :
    → Tous les cours sont récupérés
    → Sauvegardés dans Hive avec synced=true
    → Émis dans le stream → UI affiche les cours

Si échec (offline) :
    → Erreur ignorée silencieusement
    → Hive reste vide → UI affiche "Aucun cours"
    → L'utilisateur peut créer des cours offline
```

---

## 4. Fonctionnement de la Synchronisation

La synchronisation est **automatique** et se déclenche dans deux cas :

1. **Au passage offline → online** (détecté par `connectivity_plus`)
2. **Lors de chaque opération CRUD** (si online, on sync directement)

### Algorithme de syncAll()

```
Pour chaque cours dans Hive avec synced = false :
    1. Charger le document depuis Firebase (s'il existe)
    2. Comparer les dates updatedAt
    3. Si Firebase plus récent → mettre à jour Hive (version distante gagne)
    4. Si Local plus récent → envoyer vers Firebase (set avec merge)
    5. Marquer synced = true dans Hive

Pour chaque ID dans pending_course_deletes :
    1. Supprimer le document sur Firebase
    2. Retirer l'ID de la liste pending_deletes
```

La sync s'exécute **en arrière-plan** (sans `await` bloquant l'UI) grâce à l'utilisation de `unawaited` calls dans le flux de navigation.

---

## 5. Gestion des Conflits

Stratégie choisie : **"Last updatedAt wins"** (la modification la plus récente l'emporte).

### Règle
```
Si updatedAt_local > updatedAt_firebase → on envoie la version locale
Si updatedAt_firebase > updatedAt_local → on écrase le local avec Firebase
```

### Justification
C'est la stratégie la plus simple et la plus lisible pour un projet étudiant. Elle est adaptée à un usage mono-utilisateur (un seul étudiant utilise l'application). Pour un projet multi-utilisateurs, on pourrait implémenter une résolution manuelle (dialog de conflit).

### Champs clés utilisés
| Champ | Type | Rôle |
|-------|------|------|
| `id` | String (UUID) | Identifiant unique, généré localement |
| `updatedAt` | DateTime | Horodatage de la dernière modification |
| `synced` | bool | **Local uniquement** — indique si Firebase est à jour |

---

## 6. Champs Techniques Importants

### `synced`
- Stocké uniquement dans Hive
- **Jamais** envoyé à Firebase (exclu de `toMap()`)
- `false` = modification en attente → sera synchronisée au prochain `syncAll()`
- `true` = données cohérentes avec Firebase

### `id` (UUID)
- Généré localement avec le package `uuid` (format UUID v4)
- Permet de créer des enregistrements offline et de les uploader sur Firebase avec le même ID
- Remplace l'ancienne approche `collection.add()` qui nécessitait Firebase pour générer l'ID

---

## 7. Avantages de la Solution

| Avantage | Description |
|----------|-------------|
| **Réactivité immédiate** | Les opérations sont instantanées (pas d'attente réseau) |
| **Disponibilité offline** | L'app reste utilisable sans internet |
| **Synchronisation transparente** | L'utilisateur n'a pas besoin de déclencher manuellement |
| **Simple à comprendre** | Architecture en couches claire : UI → Repo → Local → Cloud |
| **Pas de code generation** | Hive utilisé avec JSON strings, aucun build_runner requis |
| **Rétrocompatible** | Les anciens services (CourseService, HomeworkService) sont conservés |

---

## 8. Limites et Améliorations Possibles

| Limite | Amélioration Possible |
|--------|-----------------------|
| Pas de suppression offline parfaite (dépend des pending deletes) | Soft delete avec champ `deletedAt` |
| Pas de résolution de conflits manuelle | Dialog de merge pour conflits complexes |
| Sync mono-directionnelle (local → Firebase) | Écoute Firestore pour pull en temps réel |
| Pas de pagination | Charger par batches pour les grandes listes |
| Pas de chiffrement local | Hive avec chiffrement pour données sensibles |

---

## 9. Guide d'Intégration et d'Exécution

### Étape 1 — Installer les packages
```bash
flutter pub get
```

### Étape 2 — Vérifier la configuration Firebase
Le fichier `android/app/google-services.json` est déjà présent dans le projet original.
Aucune modification n'est nécessaire si le projet Firebase est déjà configuré.

### Étape 3 — Lancer l'application
```bash
flutter run
```

### Structure des nouveaux fichiers ajoutés

```
lib/
├── main.dart                          ← MODIFIÉ (init Hive + SyncService)
├── models/
│   ├── course.dart                    ← MODIFIÉ (champ synced, toLocalMap, fromLocalMap)
│   └── homework.dart                  ← MODIFIÉ (idem)
├── services/
│   ├── local_service.dart             ← NOUVEAU (Hive CRUD)
│   ├── sync_service.dart              ← NOUVEAU (connectivity + sync Firebase)
│   ├── course_service.dart            ← CONSERVÉ (inchangé)
│   ├── homework_service.dart          ← CONSERVÉ (inchangé)
│   └── firestore_service.dart         ← CONSERVÉ (inchangé)
├── repositories/
│   ├── course_repository.dart         ← NOUVEAU (orchestre local + remote)
│   └── homework_repository.dart       ← NOUVEAU (idem)
└── screens/
    ├── home_screen.dart               ← MODIFIÉ (bandeau offline)
    ├── course_list_screen.dart        ← MODIFIÉ (utilise CourseRepository)
    ├── homework_list_screen.dart      ← MODIFIÉ (utilise HomeworkRepository)
    ├── course_form_screen.dart        ← MODIFIÉ (idem)
    └── homework_form_screen.dart      ← MODIFIÉ (idem)
```

---

## 10. Guide de Test

### Test 1 — Premier Lancement (local vide)
```
Prérequis : données existantes dans Firebase

1. Désinstaller l'application (vide le Hive)
2. Activer le WiFi
3. Lancer l'app
→ Résultat attendu : les données Firebase apparaissent
→ Vérifier dans les logs : "X cours chargés depuis Firebase"
```

### Test 2 — Mode OFFLINE
```
1. Lancer l'app en ligne (données chargées)
2. Désactiver le WiFi / mode avion
3. Naviguer dans l'app
→ Résultat attendu :
  • Bandeau orange "Mode hors ligne" visible en haut
  • Les cours et devoirs sont toujours affichés (depuis Hive)
  • On peut ajouter un cours → apparaît immédiatement (icône 🟠)
  • On peut modifier, supprimer
```

### Test 3 — Synchronisation automatique
```
1. Rester en mode avion
2. Ajouter 2-3 cours (ils ont l'icône cloud_upload orange)
3. Réactiver le WiFi
→ Résultat attendu :
  • Snackbar "Connexion rétablie — synchronisation en cours..."
  • Les icônes passent de 🟠 (cloud_upload) à 🟢 (cloud_done)
  • Ouvrir Firebase Console → les nouvelles données sont présentes
```

### Test 4 — Gestion des conflits
```
1. Modifier un cours en ligne → le champ updatedAt est mis à jour sur Firebase
2. Passer offline
3. Modifier le même cours en local (updatedAt local = maintenant = plus récent)
4. Repasser online
→ Résultat attendu : la version locale (plus récente) est envoyée sur Firebase
```

### Icônes d'état de synchronisation dans l'UI
| Icône | Couleur | Signification |
|-------|---------|---------------|
| ☁️✓ (cloud_done) | Vert | Synchronisé avec Firebase |
| ☁️↑ (cloud_upload) | Orange | En attente de synchronisation |
