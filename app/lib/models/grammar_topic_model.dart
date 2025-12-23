class GrammarTopicModel {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final String? teacherId;

  GrammarTopicModel({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    this.teacherId,
  });

  factory GrammarTopicModel.fromJson(Map<String, dynamic> json) {
    return GrammarTopicModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      teacherId: json['teacher_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'teacher_id': teacherId,
    };
  }
}

