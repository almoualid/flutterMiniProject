// lib/screens/homework_form_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_academic_manager/models/homework.dart';
import 'package:student_academic_manager/models/course.dart';
import 'package:student_academic_manager/repositories/homework_repository.dart';
import 'package:student_academic_manager/repositories/course_repository.dart';
import 'package:student_academic_manager/exceptions/app_exception.dart';

class HomeworkFormScreen extends StatefulWidget {
  final Homework? homework;
  const HomeworkFormScreen({Key? key, this.homework}) : super(key: key);

  @override
  State<HomeworkFormScreen> createState() => _HomeworkFormScreenState();
}

class _HomeworkFormScreenState extends State<HomeworkFormScreen> {
  late final GlobalKey<FormState> _formKey;
  
  late final HomeworkRepository _homeworkRepository;
  late final CourseRepository   _courseRepository;

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late DateTime _selectedDeadline;
  late String   _selectedCourseId;
  late bool     _isDone;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _homeworkRepository = HomeworkRepository();
    _courseRepository   = CourseRepository();

    _titleController = TextEditingController(text: widget.homework?.title ?? '');
    _descriptionController = TextEditingController(text: widget.homework?.description ?? '');

    _selectedDeadline = widget.homework?.deadline ?? DateTime.now().add(const Duration(days: 7));
    _selectedCourseId = widget.homework?.courseId ?? '';
    _isDone = widget.homework?.isDone ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadlineDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDeadline = picked);
  }

  Future<void> _saveHomework() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un cours')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final hw = Homework(
        id: widget.homework?.id ?? '',
        title: _titleController.text.trim(),
        deadline: _selectedDeadline,
        isDone: _isDone,
        courseId: _selectedCourseId,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (widget.homework == null) {
        await _homeworkRepository.add(hw);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Devoir "${hw.title}" ajouté'),
              backgroundColor: Theme.of(context).colorScheme.primary),
        );
      } else {
        await _homeworkRepository.update(hw);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Devoir "${hw.title}" mis à jour'),
              backgroundColor: Theme.of(context).colorScheme.primary),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Une erreur inattendue s\'est produite')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.homework != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Modifier le devoir' : 'Ajouter un devoir'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Titre
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Titre du devoir',
                  hintText: 'ex : Exercices chapitre 5',
                  prefixIcon: const Icon(Icons.assignment),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Entrez un titre';
                  if (v.trim().length < 3) return 'Minimum 3 caractères';
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optionnel)',
                  hintText: 'ex : Pages 45-50, questions 1-5',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLines: 3,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Sélecteur de cours — stream depuis Hive (offline-first)
              StreamBuilder<List<Course>>(
                stream: _courseRepository.getAll(),
                builder: (context, snapshot) {
                  final courses = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: _selectedCourseId.isEmpty ? null : _selectedCourseId,
                    decoration: InputDecoration(
                      labelText: 'Cours',
                      prefixIcon: const Icon(Icons.class_),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: courses
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) { if (v != null) setState(() => _selectedCourseId = v); },
                    validator: (v) => (v == null || v.isEmpty) ? 'Sélectionnez un cours' : null,
                    isExpanded: true,
                  );
                },
              ),
              const SizedBox(height: 16),

              // Date limite
              GestureDetector(
                onTap: _isLoading ? null : _selectDeadlineDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date limite',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_selectedDeadline),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Switch fait/non fait
              Card(
                margin: EdgeInsets.zero,
                child: SwitchListTile(
                  title: const Text('Marquer comme fait'),
                  subtitle: Text(_isDone ? 'Devoir terminé' : 'Devoir à faire',
                      style: Theme.of(context).textTheme.bodySmall),
                  value: _isDone,
                  onChanged: _isLoading ? null : (v) => setState(() => _isDone = v),
                  activeColor: Colors.green,
                ),
              ),
              const SizedBox(height: 32),

              // Bouton sauvegarder
              ElevatedButton(
                onPressed: _isLoading ? null : _saveHomework,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : Text(isEditMode ? 'Mettre à jour' : 'Ajouter',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Annuler',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
