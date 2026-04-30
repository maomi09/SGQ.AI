class ClassModel {
  final String id;
  final String name;
  final String code;
  final String teacherId;
  final bool aiHelperEnabled;
  final int completionQuestionTarget;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClassModel({
    required this.id,
    required this.name,
    required this.code,
    required this.teacherId,
    this.aiHelperEnabled = true,
    this.completionQuestionTarget = 5,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      teacherId: json['teacher_id'] as String,
      aiHelperEnabled: json['ai_helper_enabled'] as bool? ?? true,
      completionQuestionTarget:
          (json['completion_question_target'] as num?)?.toInt() ?? 5,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'teacher_id': teacherId,
      'ai_helper_enabled': aiHelperEnabled,
      'completion_question_target': completionQuestionTarget,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ClassModel copyWith({
    String? id,
    String? name,
    String? code,
    String? teacherId,
    bool? aiHelperEnabled,
    int? completionQuestionTarget,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      teacherId: teacherId ?? this.teacherId,
      aiHelperEnabled: aiHelperEnabled ?? this.aiHelperEnabled,
      completionQuestionTarget:
          completionQuestionTarget ?? this.completionQuestionTarget,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
