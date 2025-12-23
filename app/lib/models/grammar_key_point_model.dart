class GrammarKeyPointModel {
  final String id;
  final String grammarTopicId;
  final String title;
  final String content;
  final int order;
  final DateTime createdAt;

  GrammarKeyPointModel({
    required this.id,
    required this.grammarTopicId,
    required this.title,
    required this.content,
    required this.order,
    required this.createdAt,
  });

  factory GrammarKeyPointModel.fromJson(Map<String, dynamic> json) {
    return GrammarKeyPointModel(
      id: json['id'] as String,
      grammarTopicId: json['grammar_topic_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      order: json['order'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'grammar_topic_id': grammarTopicId,
      'title': title,
      'content': content,
      'order': order,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

