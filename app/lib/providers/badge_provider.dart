import 'package:flutter/foundation.dart';
import '../models/badge_model.dart';
import '../services/supabase_service.dart';

class BadgeProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  List<BadgeModel> _badges = [];
  bool _isLoading = false;

  List<BadgeModel> get badges => _badges;
  bool get isLoading => _isLoading;

  Future<void> loadBadges(String studentId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _badges = await _supabaseService.getBadges(studentId);
    } catch (e) {
      // Handle error
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> checkAndAwardBadge(String studentId, String grammarTopicId) async {
    final progress = await _supabaseService.getStudentProgress(studentId, grammarTopicId);
    final completedCount = progress['completed_questions'] as int;

    if (completedCount == 3 && !_hasBadgeForTopic(grammarTopicId, 'first_3_completed')) {
      await _awardBadge(studentId, grammarTopicId, 'first_3_completed', '完成3題', '恭喜完成3題文法練習！');
    } else if (completedCount == 10 && !_hasBadgeForTopic(grammarTopicId, 'first_10_completed')) {
      await _awardBadge(studentId, grammarTopicId, 'first_10_completed', '完成10題', '恭喜完成10題文法練習！');
    } else if (completedCount == 20 && !_hasBadgeForTopic(grammarTopicId, 'first_20_completed')) {
      await _awardBadge(studentId, grammarTopicId, 'first_20_completed', '完成20題', '恭喜完成20題文法練習！');
    }

    await loadBadges(studentId);
  }

  bool _hasBadgeForTopic(String grammarTopicId, String badgeType) {
    return _badges.any((badge) => 
      badge.grammarTopicId == grammarTopicId && badge.badgeType == badgeType);
  }

  Future<void> _awardBadge(String studentId, String grammarTopicId, String badgeType, String badgeName, String description) async {
    final badge = BadgeModel(
      id: '',
      studentId: studentId,
      badgeType: badgeType,
      badgeName: badgeName,
      description: description,
      earnedAt: DateTime.now(),
      grammarTopicId: grammarTopicId,
    );
    await _supabaseService.createBadge(badge);
  }
}

