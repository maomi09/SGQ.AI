import 'dart:convert';

enum QuestionType {
  multipleChoice,
  shortAnswer,
}

class QuestionModel {
  final String id;
  final String studentId;
  final String grammarTopicId;
  final QuestionType type;
  final String question;
  final List<String>? options; // For multiple choice
  final String? correctAnswer;
  final String? explanation;
  final int stage; // 1-4, which stage the question is at
  final Map<int, DateTime>? completedStages; // 追蹤每個階段的完成時間
  final String? teacherComment; // 教師評語
  final DateTime? teacherCommentUpdatedAt; // 評語更新時間
  final DateTime createdAt;
  final DateTime? updatedAt;

  QuestionModel({
    required this.id,
    required this.studentId,
    required this.grammarTopicId,
    required this.type,
    required this.question,
    this.options,
    this.correctAnswer,
    this.explanation,
    required this.stage,
    this.completedStages,
    this.teacherComment,
    this.teacherCommentUpdatedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      grammarTopicId: json['grammar_topic_id'] as String,
      type: QuestionType.values.firstWhere(
        (e) => e.toString() == 'QuestionType.${json['type']}',
        orElse: () => QuestionType.multipleChoice,
      ),
      question: json['question'] as String,
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : null,
      correctAnswer: json['correct_answer'] as String?,
      explanation: json['explanation'] as String?,
      stage: json['stage'] as int,
      completedStages: json['completed_stages'] != null
          ? _parseCompletedStages(json['completed_stages'])
          : null,
      teacherComment: json['teacher_comment'] as String?,
      teacherCommentUpdatedAt: json['teacher_comment_updated_at'] != null
          ? DateTime.parse(json['teacher_comment_updated_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'grammar_topic_id': grammarTopicId,
      'type': type.toString().split('.').last,
      'question': question,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'stage': stage,
      'completed_stages': completedStages != null
          ? completedStages!.map((key, value) => MapEntry(key.toString(), value.toIso8601String()))
          : null,
      'teacher_comment': teacherComment,
      'teacher_comment_updated_at': teacherCommentUpdatedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static Map<int, DateTime> _parseCompletedStages(dynamic json) {
    final Map<int, DateTime> result = {};
    
    if (json == null) return result;
    
    // 處理不同的 JSONB 格式
    Map<String, dynamic>? map;
    if (json is Map) {
      map = json.cast<String, dynamic>();
    } else if (json is String) {
      // 如果是字符串，嘗試解析為 JSON
      try {
        final decoded = jsonDecode(json);
        if (decoded is Map) {
          map = decoded.cast<String, dynamic>();
        }
      } catch (e) {
        print('Error parsing completed_stages JSON: $e');
        return result;
      }
    }
    
    if (map != null) {
      map.forEach((key, value) {
        final stage = int.tryParse(key);
        if (stage != null) {
          if (value is String) {
            try {
              result[stage] = DateTime.parse(value);
            } catch (e) {
              print('Error parsing date for stage $stage: $e');
            }
          }
        }
      });
    }
    
    return result;
  }
}

