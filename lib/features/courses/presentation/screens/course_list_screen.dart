import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:student_companion/features/courses/data/models/course.dart';
import 'package:student_companion/features/courses/data/repositories/course_repository.dart';
import 'package:student_companion/exceptions/app_exception.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

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
    context.push('/courses/add');
  }

  void _navigateToEditCourse(Course course) {
    context.push('/courses/edit', extra: course);
  }

  void _deleteCourse(Course course) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le cours', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Voulez-vous vraiment supprimer "${course.name}" ?\n\nAttention : Les devoirs associés seront également supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _courseRepository.delete(course.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cours "${course.name}" supprimé.'),
                    behavior: SnackBarBehavior.floating,
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
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
                  const SizedBox(height: 16),
                  Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
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
                  Icon(Icons.class_outlined, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text('Aucun cours', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Appuyez sur + pour ajouter un cours', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.book_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(course.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Prof: ${course.teacher}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 14, color: Theme.of(context).colorScheme.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  '${course.day} • ${course.time}',
                                  style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                if (!course.synced) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.cloud_upload_outlined, size: 14, color: Colors.orange),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 20),
                            onPressed: () => _navigateToEditCourse(course),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, size: 20, color: Theme.of(context).colorScheme.error),
                            onPressed: () => _deleteCourse(course),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddCourse,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
