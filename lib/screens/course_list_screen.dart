// lib/screens/course_list_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// CHANGEMENT PAR RAPPORT À L'ORIGINAL :
//   • CourseService → CourseRepository
//   • Le stream vient maintenant de Hive (offline-first), pas de Firestore
//   • Ajout d'un petit indicateur synced/non-synced sur chaque carte
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:student_academic_manager/models/course.dart';
import 'package:student_academic_manager/repositories/course_repository.dart';
import 'package:student_academic_manager/screens/course_form_screen.dart';
import 'package:student_academic_manager/exceptions/app_exception.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({Key? key}) : super(key: key);

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  late final CourseRepository _courseRepository;

  @override
  void initState() {
    super.initState();
    _courseRepository = CourseRepository();
  }

  void _navigateToAddCourse() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const CourseFormScreen()));
  }

  void _navigateToEditCourse(Course course) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => CourseFormScreen(course: course)),
    );
  }

  void _deleteCourse(Course course) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le cours'),
        content: Text(
          'Supprimer "${course.name}" ?\n\nAttention : Les devoirs associés à ce cours seront également supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _courseRepository.delete(course.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cours "${course.name}" et ses devoirs associés supprimés',
                    ),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              } on AppException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur : ${e.message}')),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cours'),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<List<Course>>(
        stream: _courseRepository.getAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text('Erreur lors du chargement'),
                  Text(snapshot.error.toString()),
                ],
              ),
            );
          }

          final courses = snapshot.data ?? [];

          if (courses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.class_,
                    size: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun cours',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Appuyez sur + pour ajouter un cours',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),

                  // Indicateur de synchronisation
                  leading: Icon(
                    course.synced ? Icons.cloud_done : Icons.cloud_upload,
                    color: course.synced ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  title: Text(
                    course.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Prof : ${course.teacher}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${course.day} • ${course.time}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                          ),
                        ],
                      ),
                      // Texte si non synchronisé
                      if (!course.synced)
                        const Text(
                          'En attente de synchronisation',
                          style: TextStyle(fontSize: 10, color: Colors.orange),
                        ),
                    ],
                  ),
                  trailing: SizedBox(
                    width: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: () => _navigateToEditCourse(course),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => _deleteCourse(course),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddCourse,
        tooltip: 'Ajouter un cours',
        child: const Icon(Icons.add),
      ),
    );
  }
}
