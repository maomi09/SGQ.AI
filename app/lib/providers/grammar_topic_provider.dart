import 'package:flutter/foundation.dart';
import '../models/grammar_topic_model.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';

class GrammarTopicProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  List<GrammarTopicModel> _topics = [];
  GrammarTopicModel? _selectedTopic;
  bool _isLoading = false;

  List<GrammarTopicModel> get topics => _topics;
  GrammarTopicModel? get selectedTopic => _selectedTopic;
  bool get isLoading => _isLoading;

  Future<void> loadTopics() async {
    _isLoading = true;
    notifyListeners();

    try {
      _topics = await _supabaseService.getGrammarTopics();
    } catch (e) {
      // Handle error
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectTopic(String topicId) async {
    if (topicId.isEmpty) {
      _selectedTopic = null;
      notifyListeners();
      return;
    }
    _selectedTopic = await _supabaseService.getGrammarTopic(topicId);
    notifyListeners();
  }

  Future<void> createTopic(String title, String description, String teacherId) async {
    await _supabaseService.createGrammarTopic(title, description, teacherId);
    await loadTopics();
    
    // 發送通知給所有學生
    try {
      final students = await _supabaseService.getAllStudents();
      final notificationService = NotificationService();
      
      for (var student in students) {
        await notificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch + student['id'].hashCode,
          title: '新課程上線',
          body: '老師已建立新課程「$title」，快來查看吧！',
        );
      }
    } catch (e) {
      print('發送課程通知失敗: $e');
      // 不影響課程建立流程，只記錄錯誤
    }
  }

  Future<void> updateTopic(String id, String title, String description) async {
    await _supabaseService.updateGrammarTopic(id, title, description);
    await loadTopics();
  }

  Future<void> deleteTopic(String id) async {
    try {
      await _supabaseService.deleteGrammarTopic(id);
      await loadTopics();
    } catch (e) {
      rethrow;
    }
  }
}

