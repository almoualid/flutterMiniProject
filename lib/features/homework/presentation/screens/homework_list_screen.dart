import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:student_companion/features/courses/data/models/course.dart';
import 'package:student_companion/features/courses/data/repositories/course_repository.dart';
import 'package:student_companion/features/homework/data/models/homework.dart';
import 'package:student_companion/features/homework/data/repositories/homework_repository.dart';
import 'package:student_companion/exceptions/app_exception.dart';

class HomeworkListScreen extends StatefulWidget {
  const HomeworkListScreen({super.key});

  @override
  State<HomeworkListScreen> createState() => _HomeworkListScreenState();
}

class _HomeworkListScreenState extends State<HomeworkListScreen> {
  late final HomeworkRepository _homeworkRepository;
  late final CourseRepository _courseRepository;
  late Future<Map<String, Course?>> _coursesCache;

  @override
  void initState() {
    super.initState();
    _homeworkRepository = HomeworkRepository();
    _courseRepository = CourseRepository();
    _coursesCache = _loadAllCourses();
  }

  Future<Map<String, Course?>> _loadAllCourses() async {
    final courses = await _courseRepository.getAll().first;
    return {for (var course in courses) course.id: course};
  }

  void _navigateToAddHomework() {
    context.push('/homeworks/add');
  }

  void _navigateToEditHomework(Homework homework) {
    context.push('/homeworks/edit', extra: homework);
  }

  void _deleteHomework(Homework homework) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le devoir', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Supprimer "${homework.title}" ?'),
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
                await _homeworkRepository.delete(homework.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Devoir "${homework.title}" supprimé.'),
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

  void _toggleHomeworkStatus(Homework homework) async {
    try {
      await _homeworkRepository.toggleStatus(homework.id, !homework.isDone);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${e.message}')),
      );
    }
  }

  Widget _buildCourseName(String courseId, Map<String, Course?> coursesMap) {
    final course = coursesMap[courseId];
    return Text(
      course?.name ?? 'Cours inconnu',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  String _getDeadlineStatus(DateTime deadline) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final d = DateTime(deadline.year, deadline.month, deadline.day);
    if (d.isBefore(today)) return 'En retard';
    if (d.isAtSameMomentAs(today)) return 'Aujourd\'hui';
    return 'À venir';
  }

  Color _getDeadlineColor(DateTime deadline) {
    final status = _getDeadlineStatus(deadline);
    if (status == 'En retard') return Theme.of(context).colorScheme.error;
    if (status == 'Aujourd\'hui') return Colors.orange;
    return Theme.of(context).colorScheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, Course?>>(
        future: _coursesCache,
        builder: (context, coursesSnapshot) {
          return StreamBuilder<List<Homework>>(
            stream: _homeworkRepository.getAll(),
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

              final homeworks = snapshot.data ?? [];
              final coursesMap = coursesSnapshot.data ?? {};

              if (homeworks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text('Aucun devoir', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('Appuyez sur + pour ajouter un devoir', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: homeworks.length,
                itemBuilder: (context, index) {
                  final hw = homeworks[index];
                  final deadlineColor = _getDeadlineColor(hw.deadline);
                  final deadlineStatus = _getDeadlineStatus(hw.deadline);

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: hw.isDone 
                            ? Colors.transparent 
                            : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: hw.isDone ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _toggleHomeworkStatus(hw),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: hw.isDone ? Colors.green : Theme.of(context).colorScheme.outline,
                                  width: 2,
                                ),
                                color: hw.isDone ? Colors.green : Colors.transparent,
                              ),
                              child: hw.isDone ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hw.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    decoration: hw.isDone ? TextDecoration.lineThrough : null,
                                    color: hw.isDone ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildCourseName(hw.courseId, coursesMap),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.event_rounded, size: 14, color: hw.isDone ? Colors.grey : deadlineColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${DateFormat('dd/MM/yyyy').format(hw.deadline)} • $deadlineStatus',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: hw.isDone ? Colors.grey : deadlineColor,
                                      ),
                                    ),
                                    if (!hw.synced) ...[
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
                                onPressed: () => _navigateToEditHomework(hw),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, size: 20, color: Theme.of(context).colorScheme.error),
                                onPressed: () => _deleteHomework(hw),
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddHomework,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
