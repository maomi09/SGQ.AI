class GrammarTopicModel {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final String? teacherId;
  final String? classId;
  final int completionQuestionTarget;

  GrammarTopicModel({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    this.teacherId,
    this.classId,
    this.completionQuestionTarget = 5,
  });

  factory GrammarTopicModel.fromJson(Map<String, dynamic> json) {
    return GrammarTopicModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      teacherId: json['teacher_id'] as String?,
      classId: json['class_id'] as String?,
      completionQuestionTarget:
          (json['completion_question_target'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'teacher_id': teacherId,
      'class_id': classId,
      'completion_question_target': completionQuestionTarget,
    };
  }

  GrammarTopicModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    String? teacherId,
    String? classId,
    int? completionQuestionTarget,
  }) {
    return GrammarTopicModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      teacherId: teacherId ?? this.teacherId,
      classId: classId ?? this.classId,
      completionQuestionTarget:
          completionQuestionTarget ?? this.completionQuestionTarget,
    );
  }
}

