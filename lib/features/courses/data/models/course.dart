class Course {
  final String id;
  final String name;
  final String teacher;
  final String day;
  final String time;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool synced;

  const Course({
    required this.id,
    required this.name,
    required this.teacher,
    required this.day,
    required this.time,
    this.createdAt,
    this.updatedAt,
    this.synced = false,
  });

  factory Course.fromMap(Map<String, dynamic> map, String documentId) {
    return Course(
      id: documentId,
      name: map['name'] as String? ?? '',
      teacher: map['teacher'] as String? ?? '',
      day: map['day'] as String? ?? '',
      time: map['time'] as String? ?? '',
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
      'name': name,
      'teacher': teacher,
      'day': day,
      'time': time,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Course.fromLocalMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      teacher: map['teacher'] as String? ?? '',
      day: map['day'] as String? ?? '',
      time: map['time'] as String? ?? '',
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
      'name': name,
      'teacher': teacher,
      'day': day,
      'time': time,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'synced': synced,   
    };
  }

  Course copyWith({
    String? id,
    String? name,
    String? teacher,
    String? day,
    String? time,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      day: day ?? this.day,
      time: time ?? this.time,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }
}
