class BadgeModel {
  final String id;
  final String studentId;
  final String badgeType; // 'bronze', 'silver', 'gold'
  final String badgeName;
  final String description;
  final DateTime earnedAt;
  final String grammarTopicId;

  BadgeModel({
    required this.id,
    required this.studentId,
    required this.badgeType,
    required this.badgeName,
    required this.description,
    required this.earnedAt,
    required this.grammarTopicId,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      badgeType: json['badge_type'] as String,
      badgeName: json['badge_name'] as String,
      description: json['description'] as String,
      earnedAt: DateTime.parse(json['earned_at'] as String),
      grammarTopicId: json['grammar_topic_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'student_id': studentId,
      'badge_type': badgeType,
      'badge_name': badgeName,
      'description': description,
      'earned_at': earnedAt.toIso8601String(),
      'grammar_topic_id': grammarTopicId,
    };
    // 只有在 id 不為空時才包含它（讓資料庫自動生成 UUID）
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  // 獲取獎牌類型的中文名稱
  String get medalName {
    switch (badgeType) {
      case 'bronze':
        return '銅牌';
      case 'silver':
        return '銀牌';
      case 'gold':
        return '金牌';
      default:
        return badgeType;
    }
  }

  // 獲取獎牌說明
  String get medalDescription {
    switch (badgeType) {
      case 'bronze':
        return '銅牌代表良好的學習表現，是對您努力的肯定。';
      case 'silver':
        return '銀牌代表優秀的學習成果，展現了您的持續進步。';
      case 'gold':
        return '金牌代表卓越的學習成就，是對您傑出表現的最高肯定。';
      default:
        return description;
    }
  }
}

