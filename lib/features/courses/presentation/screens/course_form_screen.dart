import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:student_companion/features/courses/data/models/course.dart';
import 'package:student_companion/features/courses/data/repositories/course_repository.dart';
import 'package:student_companion/exceptions/app_exception.dart';

class CourseFormScreen extends StatefulWidget {
  final Course? course;
  const CourseFormScreen({super.key, this.course});

  @override
  State<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends State<CourseFormScreen> {
  late final GlobalKey<FormState> _formKey;
  late final CourseRepository _courseRepository;

  late final TextEditingController _nameController;
  late final TextEditingController _teacherController;
  late String _selectedDay;
  late TimeOfDay _selectedTime;
  bool _isLoading = false;

  static const List<String> _days = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi',
  ];

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _courseRepository = CourseRepository();

    _nameController = TextEditingController(text: widget.course?.name ?? '');
    _teacherController = TextEditingController(text: widget.course?.teacher ?? '');

    final timeStr = widget.course?.time ?? '08:00';
    final parts = timeStr.split(':');
    _selectedTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    _selectedDay = widget.course?.day ?? 'Lundi';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _selectTime() async {
    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final course = Course(
        id: widget.course?.id ?? '',
        name: _nameController.text.trim(),
        teacher: _teacherController.text.trim(),
        day: _selectedDay,
        time: _formatTime(_selectedTime),
      );

      if (widget.course == null) {
        await _courseRepository.add(course);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cours "${course.name}" ajouté'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        await _courseRepository.update(course);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cours "${course.name}" mis à jour'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (!mounted) return;
      context.pop();
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
    final isEditMode = widget.course != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Modifier le cours' : 'Ajouter un cours'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nom du cours',
                  hintText: 'ex : Mathématiques',
                  prefixIcon: const Icon(Icons.book_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Entrez un nom de cours';
                  if (v.trim().length < 2) return 'Minimum 2 caractères';
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _teacherController,
                decoration: InputDecoration(
                  labelText: 'Professeur',
                  hintText: 'ex : M. Dupont',
                  prefixIcon: const Icon(Icons.person_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Entrez un nom de professeur';
                  if (v.trim().length < 2) return 'Minimum 2 caractères';
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _days.contains(_selectedDay) ? _selectedDay : _days.first,
                decoration: InputDecoration(
                  labelText: 'Jour de la semaine',
                  prefixIcon: const Icon(Icons.calendar_today_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
                items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) { if (v != null) setState(() => _selectedDay = v); },
                validator: (v) => (v == null || v.isEmpty) ? 'Sélectionnez un jour' : null,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isLoading ? null : _selectTime,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Heure',
                    prefixIcon: const Icon(Icons.access_time_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  ),
                  child: Text(_formatTime(_selectedTime),
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isLoading ? null : _saveCourse,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                onPressed: _isLoading ? null : () => context.pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
