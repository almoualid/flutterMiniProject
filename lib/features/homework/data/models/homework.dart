class Homework {
  final String id;
  final String title;
  final DateTime deadline;
  final bool isDone;
  final String courseId;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool synced;

  const Homework({
    required this.id,
    required this.title,
    required this.deadline,
    required this.isDone,
    required this.courseId,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.synced = false,
  });

  factory Homework.fromMap(Map<String, dynamic> map, String documentId) {
    return Homework(
      id: documentId,
      title: map['title'] as String? ?? '',
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : DateTime.now().add(const Duration(days: 7)),
      isDone: map['isDone'] as bool? ?? false,
      courseId: map['courseId'] as String? ?? '',
      description: map['description'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
      synced: true, 
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'deadline': deadline.toIso8601String(),
      'isDone': isDone,
      'courseId': courseId,
      'description': description,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Homework.fromLocalMap(Map<String, dynamic> map) {
    return Homework(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : DateTime.now().add(const Duration(days: 7)),
      isDone: map['isDone'] as bool? ?? false,
      courseId: map['courseId'] as String? ?? '',
      description: map['description'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
      synced: map['synced'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'title': title,
      'deadline': deadline.toIso8601String(),
      'isDone': isDone,
      'courseId': courseId,
      'description': description,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'synced': synced,
    };
  }

  Homework copyWith({
    String? id,
    String? title,
    DateTime? deadline,
    bool? isDone,
    String? courseId,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return Homework(
      id: id ?? this.id,
      title: title ?? this.title,
      deadline: deadline ?? this.deadline,
      isDone: isDone ?? this.isDone,
      courseId: courseId ?? this.courseId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }
}
