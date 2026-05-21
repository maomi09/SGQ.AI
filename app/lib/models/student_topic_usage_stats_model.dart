class StudentTopicUsageStatsModel {
  final String studentId;
  final String grammarTopicId;
  final int questionCompletionCount;
  final int totalQuestionCompletionSeconds;
  final int questionEditCount;
  final int loginCount;
  final int totalSessionMinutes;
  final int grammarKeyPointViewCount;
  final int reminderViewCount;
  final DateTime? updatedAt;

  const StudentTopicUsageStatsModel({
    required this.studentId,
    required this.grammarTopicId,
    this.questionCompletionCount = 0,
    this.totalQuestionCompletionSeconds = 0,
    this.questionEditCount = 0,
    this.loginCount = 0,
    this.totalSessionMinutes = 0,
    this.grammarKeyPointViewCount = 0,
    this.reminderViewCount = 0,
    this.updatedAt,
  });

  factory StudentTopicUsageStatsModel.fromJson(Map<String, dynamic> json) {
    return StudentTopicUsageStatsModel(
      studentId: json['student_id'] as String,
      grammarTopicId: json['grammar_topic_id'] as String,
      questionCompletionCount:
          (json['question_completion_count'] as num?)?.toInt() ?? 0,
      totalQuestionCompletionSeconds:
          (json['total_question_completion_seconds'] as num?)?.toInt() ?? 0,
      questionEditCount: (json['question_edit_count'] as num?)?.toInt() ?? 0,
      loginCount: (json['login_count'] as num?)?.toInt() ?? 0,
      totalSessionMinutes: (json['total_session_minutes'] as num?)?.toInt() ?? 0,
      grammarKeyPointViewCount:
          (json['grammar_key_point_view_count'] as num?)?.toInt() ?? 0,
      reminderViewCount: (json['reminder_view_count'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  double get averageQuestionCompletionSeconds {
    if (questionCompletionCount <= 0) return 0;
    return totalQuestionCompletionSeconds / questionCompletionCount;
  }

  double get averageSessionMinutes {
    if (loginCount <= 0) return 0;
    return totalSessionMinutes / loginCount;
  }
}
