// lib/screens/homework_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_academic_manager/models/homework.dart';
import 'package:student_academic_manager/models/course.dart';
import 'package:student_academic_manager/repositories/homework_repository.dart';
import 'package:student_academic_manager/repositories/course_repository.dart';
import 'package:student_academic_manager/screens/homework_form_screen.dart';
import 'package:student_academic_manager/exceptions/app_exception.dart';

class HomeworkListScreen extends StatefulWidget {
  const HomeworkListScreen({Key? key}) : super(key: key);

  @override
  State<HomeworkListScreen> createState() => _HomeworkListScreenState();
}

class _HomeworkListScreenState extends State<HomeworkListScreen> {
  late final HomeworkRepository _homeworkRepository;
  late final CourseRepository   _courseRepository;

  @override
  void initState() {
    super.initState();
    _homeworkRepository = HomeworkRepository();
    _courseRepository   = CourseRepository();
  }

  void _navigateToAddHomework() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const HomeworkFormScreen()),
    );
  }

  void _navigateToEditHomework(Homework homework) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => HomeworkFormScreen(homework: homework)),
    );
  }

  void _deleteHomework(Homework homework) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le devoir'),
        content: Text('Supprimer "${homework.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _homeworkRepository.delete(homework.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Devoir "${homework.title}" supprimé'),
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

  /// Lit le nom du cours depuis le stockage local (pas besoin de Future car Hive est synchrone)
  Widget _buildCourseName(String courseId) {
    return FutureBuilder<Course?>(
      future: _courseRepository.getById(courseId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text(
            snapshot.data?.name ?? 'Cours inconnu',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.secondary),
          );
        }
        return const Text('...', style: TextStyle(color: Colors.grey));
      },
    );
  }

  String _formatDeadline(DateTime deadline) =>
      DateFormat('dd/MM/yyyy').format(deadline);

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
      appBar: AppBar(
        title: const Text('Devoirs'),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<List<Homework>>(
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
                  Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.error, size: 64),
                  const SizedBox(height: 16),
                  Text('Erreur : ${snapshot.error}'),
                ],
              ),
            );
          }

          final homeworks = snapshot.data ?? [];

          if (homeworks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment, size: 80,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('Aucun devoir', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Appuyez sur + pour ajouter un devoir',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: homeworks.length,
            itemBuilder: (context, index) {
              final hw = homeworks[index];
              final deadlineColor = _getDeadlineColor(hw.deadline);
              final deadlineStatus = _getDeadlineStatus(hw.deadline);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Icon(
                    hw.synced ? Icons.cloud_done : Icons.cloud_upload,
                    color: hw.synced ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  title: Text(hw.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      _buildCourseName(hw.courseId),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.calendar_today, size: 14, color: deadlineColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${_formatDeadline(hw.deadline)} ($deadlineStatus)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: deadlineColor),
                          ),
                        ),
                      ]),
                      if (!hw.synced)
                        const Text('En attente de synchronisation',
                            style: TextStyle(fontSize: 10, color: Colors.orange)),
                    ],
                  ),
                  trailing: SizedBox(
                    width: 165,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _toggleHomeworkStatus(hw),
                          child: Chip(
                            label: Text(
                              hw.isDone ? 'Fait' : 'À faire',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                            backgroundColor: hw.isDone ? Colors.green : Colors.amber,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.edit, size: 18,
                              color: Theme.of(context).colorScheme.primary),
                          onPressed: () => _navigateToEditHomework(hw),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: const EdgeInsets.all(2),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, size: 18,
                              color: Theme.of(context).colorScheme.error),
                          onPressed: () => _deleteHomework(hw),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: const EdgeInsets.all(2),
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
        onPressed: _navigateToAddHomework,
        child: const Icon(Icons.add),
      ),
    );
  }
}
