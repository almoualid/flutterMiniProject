# Rapport Technique : Module « Gestion des Cours et Devoirs »

## 1. Introduction

Ce rapport décrit la conception et l'implémentation d'un module Flutter complète permettant la gestion des cours et des devoirs au sein d'une application académique mobile. Le module intègre Firebase Firestore comme système de persistence des données et fournit des opérations CRUD (Create, Read, Update, Delete) complètes pour deux entités métier : les Cours et les Devoirs. L'application offre une interface utilisateur intuitive avec des mises à jour en temps réel et une architecture de services bien structurée pour faciliter la maintenance et l'évolutivité. Ce projet démontre les bonnes pratiques en matière de développement mobile, incluant la gestion des erreurs, la validation des formulaires et la séparation des responsabilités entre les couches présentation, métier et données.

---

## 2. Architecture des données

### 2.1 Collections Firestore

L'architecture de données repose sur deux collections principales dans Firestore : **courses** et **homeworks**. Ces collections sont conçues de manière relational, où chaque devoir (Homework) référence un cours (Course) via la clé étrangère `courseId`.

### 2.2 Schéma des collections

#### Collection : **courses**

| Champ | Type | Description | Obligatoire / Optionnel |
|-------|------|-------------|--------------------|
| `id` | String | Identifiant unique généré par Firestore | Obligatoire |
| `name` | String | Nom du cours (p.ex., « Mathématiques », « Physique ») | Obligatoire |
| `teacher` | String | Nom de l'enseignant responsable du cours | Obligatoire |
| `day` | String | Jour de la semaine du cours (p.ex., « Lundi », « Mardi ») | Obligatoire |
| `time` | String | Horaire du cours au format HH:mm (p.ex., « 09:00 ») | Obligatoire |
| `createdAt` | DateTime (ISO 8601) | Timestamp de création du cours | Optionnel |
| `updatedAt` | DateTime (ISO 8601) | Timestamp de la dernière modification | Optionnel |

#### Collection : **homeworks**

| Champ | Type | Description | Obligatoire / Optionnel |
|-------|------|-------------|--------------------|
| `id` | String | Identifiant unique généré par Firestore | Obligatoire |
| `title` | String | Titre ou description du devoir | Obligatoire |
| `description` | String | Description détaillée (optionnelle du devoir) | Optionnel |
| `deadline` | DateTime (ISO 8601) | Date limite de remise (7 jours par défaut) | Obligatoire |
| `isDone` | Boolean | État d'accomplissement du devoir (true = complété) | Obligatoire |
| `courseId` | String | Identifiant du cours associé (clé étrangère) | Obligatoire |
| `createdAt` | DateTime (ISO 8601) | Timestamp de création du devoir | Optionnel |
| `updatedAt` | DateTime (ISO 8601) | Timestamp de la dernière modification | Optionnel |

### 2.3 Schéma d'association

```
┌─────────────────────┐
│     Cours           │
│─────────────────────│
│ id (PK)             │
│ name                │
│ teacher             │
│ day                 │
│ time                │
│ createdAt           │
│ updatedAt           │
└─────────────────────┘
          │
          │ (1 : N)
          │ courseId (FK)
          ↓
┌─────────────────────┐
│     Devoirs         │
│─────────────────────│
│ id (PK)             │
│ title               │
│ description         │
│ deadline            │
│ isDone              │
│ courseId (FK)       │
│ createdAt           │
│ updatedAt           │
└─────────────────────┘
```

**Relation** : Un cours peut avoir plusieurs devoirs associés. La liaison est établie via le champ `courseId` dans la collection **homeworks**, qui référence l'`id` d'un document dans la collection **courses**. Cette association permet de filtrer les devoirs par cours et d'assurer la cohérence référentielle lors des opérations de suppression.

---

## 3. Implémentation CRUD

### 3.1 Opérations CRUD pour l'entité « Cours »

#### 1. Create (Ajouter un cours)

```dart
Future<String> add(Course course)
```

**Description** : Crée un nouveau cours dans la collection Firestore avec génération automatique de l'ID et des timestamps.

#### 2. Read - All (Récupérer tous les cours)

```dart
Stream<List<Course>> getAll()
```

**Description** : Retourne un flux (Stream) de tous les cours avec mise à jour en temps réel lors de modifications.

#### 3. Read - By ID (Récupérer un cours par identifiant)

```dart
Future<Course?> getById(String id)
```

**Description** : Récupère un cours spécifique via son ID et retourne null si le cours n'existe pas.

#### 4. Update (Modifier un cours existant)

```dart
Future<void> update(Course course)
```

**Description** : Met à jour les champs d'un cours existant et actualise le timestamp `updatedAt`.

#### 5. Delete (Supprimer un cours)

```dart
Future<void> delete(String id)
```

**Description** : Supprime un cours par son identifiant avec validation de l'ID.

**Services additionnels** :

- `Stream<List<Course>> searchByTeacher(String teacherName)` : Recherche des cours par nom d'enseignant (insensible à la casse).
- `Stream<List<Course>> getCoursesByDay(String day)` : Récupère les cours d'un jour spécifique via requête Firestore.

---

### 3.2 Opérations CRUD pour l'entité « Devoir »

#### 1. Create (Ajouter un devoir)

```dart
Future<String> add(Homework homework)
```

**Description** : Crée un nouveau devoir avec association à un cours via `courseId` et génération des timestamps.

#### 2. Read - All (Récupérer tous les devoirs)

```dart
Stream<List<Homework>> getAll()
```

**Description** : Retourne un flux de tous les devoirs avec synchronisation en temps réel.

#### 3. Read - By ID (Récupérer un devoir par identifiant)

```dart
Future<Homework?> getById(String id)
```

**Description** : Récupère un devoir spécifique et retourne null en cas d'absence.

#### 4. Update (Modifier un devoir)

```dart
Future<void> update(Homework homework)
```

**Description** : Met à jour les propriétés d'un devoir existant et actualise le timestamp `updatedAt`.

#### 5. Delete (Supprimer un devoir)

```dart
Future<void> delete(String id)
```

**Description** : Supprime un devoir par son identifiant après validation.

**Services additionnels** :

- `Stream<List<Homework>> getHomeworksByCourse(String courseId)` : Récupère tous les devoirs associés à un cours en temps réel.

---

## 4. Interface utilisateur

### 4.1 Structure de navigation

L'application utilise une navigation par onglets inférieure (BottomNavigationBar) permettant l'accès à deux écrans principaux depuis l'écran d'accueil (HomeScreen).

### 4.2 Description des écrans

#### **Écran 1 : HomeScreen (Accueil)**

Écran principal servant de point d'entrée de l'application. Il contient une barre de navigation inférieure avec deux onglets : « Cours » et « Devoirs ». Cet écran gère la commutation entre les deux principales fonctionnalités via un `IndexedStack` pour maintenir l'état de chaque onglet.

#### **Écran 2 : CourseListScreen (Liste des cours)**

Affiche la liste complète des cours récupérée en temps réel via un `StreamBuilder`. Chaque cours est présenté dans une carte interactive permettant :

- **Consultation** : Visualiser les détails du cours (nom, enseignant, jour, heure).
- **Modification** : Accéder au formulaire d'édition en tapant le cours.
- **Suppression** : Supprimer le cours après confirmation dans une boîte de dialogue (AlertDialog).

Un bouton d'action flottant (FAB) en bas à droite permet d'ajouter un nouveau cours.

#### **Écran 3 : HomeworkListScreen (Liste des devoirs)**

Présente la liste de tous les devoirs avec affichage formaté des dates limites. Les fonctionnalités incluent :

- **Consultation** : Affichage du titre, de la description, de la deadline et du statut d'accomplissement (isDone).
- **Modification du statut** : Toggle interactif permettant de marquer un devoir comme complété ou non (via un switch ou checkbox).
- **Édition** : Accès au formulaire d'édition complet.
- **Suppression** : Suppression avec confirmation préalable.

Le bouton FAB permet l'ajout d'un nouveau devoir. Les devoirs complétés peuvent être visuellement distingués (p.ex., texte barré ou icône de validation).

#### **Écran 4 : CourseFormScreen (Formulaire de cours)**

Formulaire permettant la création et l'édition de cours. Contient des champs validés pour :

- Nom du cours (requis, non vide).
- Nom de l'enseignant (requis, non vide).
- Jour de la semaine (liste déroulante ou saisie).
- Heure du cours (format HH:mm).

Un bouton « Enregistrer » valide le formulaire et sauvegarde les données. Un bouton « Annuler » permet de retourner à la liste.

#### **Écran 5 : HomeworkFormScreen (Formulaire de devoir)**

Formulaire pour créer ou modifier un devoir. Fonctionnalités :

- Champs de saisie pour le titre et la description (titre requis).
- Sélecteur de date pour la deadline avec validation (date minimale = aujourd'hui).
- Sélecteur déroulant (DropdownButton) pour choisir le cours associé (requis).
- Toggle pour marquer le devoir comme complété ou non.

Validation complète des champs avant sauvegarde.

### 4.3 Décisions UX et implémentation

#### **Mises à jour en temps réel (Streams)**

Toutes les listes (courses et homeworks) utilisent des `StreamBuilder` connectés aux méthodes `getAll()` des services. Cette approche garantit une synchronisation automatique de l'interface lorsque les données changent dans Firestore, offrant une expérience utilisateur fluide et réactive.

#### **Validation des formulaires**

Les formulaires utilisent la classe `GlobalKey<FormState>` avec des champs `TextFormField` possédant des validateurs :

- Vérification de l'absence de champs vides.
- Vérification du format de l'heure (si applicable).
- Validation de la sélection du cours pour les devoirs.

Les erreurs de validation sont affichées sous chaque champ, guidant l'utilisateur vers la correction.

#### **Toggle de statut d'accomplissement**

Le champ `isDone` des devoirs peut être togglé directement depuis la liste via un widget `Switch` ou `Checkbox`. Chaque changement déclenche une mise à jour immédiate dans Firestore, sans nécessiter de naviguer vers le formulaire.

#### **Gestion des erreurs**

Une classe personnalisée `AppException` capture les erreurs métier avec messages explicites et codes d'erreur. Les erreurs Firestore sont interceptées, converties en `AppException` et affichées à l'utilisateur via des `SnackBar` ou des `AlertDialog`.

#### **Expérience de suppression sécurisée**

Avant toute suppression (cours ou devoir), une boîte de dialogue demande confirmation à l'utilisateur, prévenant les suppressions accidentelles.

#### **Feedback utilisateur (Loading & Feedback)**

Pendant les opérations asynchrones (ajout, modification, suppression), un indicateur de chargement (indicateur de progression circulaire) est affiché. Une fois terminées, un message de confirmation apparaît dans un `SnackBar`.

---

## 5. Difficultés rencontrées et solutions

### 5.1 Gestion de la cohérence référentielle entre cours et devoirs

**Difficulté** : Firestore ne supporte pas les contraintes de clé étrangère au niveau de la base de données. Lors de la suppression d'un cours, les devoirs associés restaient orphelins avec une référence `courseId` invalide. Cela créait une incohérence dans les données et des erreurs lors de l'affichage.

**Solution** : Implémentation d'une fonction de suppression en cascade au niveau applicatif. Avant de supprimer un cours, le service récupère tous les devoirs associés via `getHomeworksByCourse(courseId)` et les supprime un par un. Cette approche garantit la cohérence référentielle et évite les orphelins de données. Bien qu'elle génère plusieurs appels Firestore, elle assure l'intégrité métier.

### 5.2 Synchronisation des données en temps réel

**Difficulté** : Lors du passage de cours existants au formulaire d'édition, les modifications étaient parfois invisibles dans la liste jusqu'au rechargement manual. Les `StreamBuilder` nécessitaient une gestion soigneuse des états et des subscriptions pour éviter les fuites mémoire et les mises à jour dupliquées.

**Solution** : Utilisation de `StreamBuilder` avec gestion appropriée du lifecycle des widgets (initialisation dans `initState`, suppression des contrôleurs dans `dispose`). Les services retournent directement des streams Firestore via `.snapshots().map(...)`, assurant que tout changement est instantanément reflété. L'application maintient une architecture où chaque écran s'abonne indépendamment aux données qu'il affiche, évitant les états partagés problématiques.

### 5.3 Validation et gestion des cas limites

**Difficulté** : Les formulaires acceptaient initialement des données invalides (ID vides pour les mises à jour, cours non sélectionnés pour les devoirs). Les messages d'erreur Firestore étaient techniques et peu compréhensibles pour l'utilisateur. De plus, les débogages étaient difficiles sans messages d'erreur clairs.

**Solution** : Implémentation d'une classe `AppException` personnalisée avec codes d'erreur sémantiques (`ADD_COURSE_ERROR`, `UPDATE_HOMEWORK_ERROR`, etc.). Ajout de validations préalables au niveau des services (vérification de la non-vacuité des IDs, validation des paramètres). Les formulaires incluent des validateurs déclaratifs pour les champs texte et des vérifications de sélection pour les champs déroulants. Les messages d'erreur remontent à l'utilisateur via des `SnackBar` compréhensibles en français.

---

## 6. Conclusion

Ce module de gestion des cours et devoirs démontre une implémentation complète et professionnelle des principes CRUD au sein d'une application Flutter-Firebase. L'architecture en couches (présentation/UI, services/métier, données/Firestore) assure une séparation nette des responsabilités et facilite la maintenance future. Les fonctionnalités de synchronisation en temps réel offrent une expérience utilisateur moderne et réactive, tandis que la gestion robuste des erreurs et la validation des données garantissent la fiabilité de l'application. Les défis techniques relatifs à la cohérence référentielle, la synchronisation et la validation ont tous reçu des solutions pragmatiques et scalables. Le projet satisfait ainsi les critères d'évaluation d'un module académique fonctionnel : complet (CRUD), maintenable (architecture clean), utilisable (UX intuitive) et résilient (gestion d'erreurs).

---

**Auteur** : Projet académique Flutter + Firebase  
**Date** : Mai 2026  
**Stack technique** : Flutter, Dart, Firebase Firestore, Material Design 3
