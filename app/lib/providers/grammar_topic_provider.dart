import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/grammar_topic_model.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';

class GrammarTopicProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  List<GrammarTopicModel> _topics = [];
  GrammarTopicModel? _selectedTopic;
  bool _isLoading = false;
  RealtimeChannel? _realtimeChannel;

  List<GrammarTopicModel> get topics => _topics;
  GrammarTopicModel? get selectedTopic => _selectedTopic;
  bool get isLoading => _isLoading;

  /// 初始化 Realtime 訂閱（學生端使用）
  void initializeRealtimeSubscription() {
    // 取消現有的訂閱
    _realtimeChannel?.unsubscribe();
    
    // 訂閱 grammar_topics 表的 INSERT 事件
    _realtimeChannel = _supabaseClient
        .channel('grammar_topics_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'grammar_topics',
          callback: (payload) async {
            print('收到新課程 Realtime 事件: ${payload.newRecord}');
            await _handleNewTopicRealtime(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// 處理 Realtime 新課程事件
  Future<void> _handleNewTopicRealtime(Map<String, dynamic> newRecord) async {
    try {
      final topicId = newRecord['id'] as String;
      final title = newRecord['title'] as String? ?? '新課程';
      
      // 檢查是否已經通知過這個課程
      final prefs = await SharedPreferences.getInstance();
      final notifiedTopicIds = prefs.getStringList('notified_topic_ids') ?? [];
      
      if (!notifiedTopicIds.contains(topicId)) {
        // 顯示通知
        final notificationService = NotificationService();
        final notificationId = (topicId.hashCode % 2147483647).abs();
        await notificationService.showNotification(
          id: notificationId,
          title: '新課程上線',
          body: '老師已建立新課程「$title」，快來查看吧！',
        );
        
        // 記錄已通知的課程 ID
        notifiedTopicIds.add(topicId);
        await prefs.setStringList('notified_topic_ids', notifiedTopicIds);
        
        // 重新載入課程列表
        await loadTopics();
      }
    } catch (e) {
      print('處理 Realtime 新課程事件失敗: $e');
    }
  }

  /// 取消 Realtime 訂閱
  void disposeRealtimeSubscription() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  Future<void> loadTopics() async {
    _isLoading = true;
    notifyListeners();

    try {
      final previousTopicIds = _topics.map((t) => t.id).toSet();
      _topics = await _supabaseService.getGrammarTopics();
      
      // 檢查是否有新課程（學生端）
      final newTopics = _topics.where((topic) => !previousTopicIds.contains(topic.id)).toList();
      if (newTopics.isNotEmpty && previousTopicIds.isNotEmpty) {
        // 只在學生端顯示通知（檢查是否有已載入過的課程）
        await _checkAndNotifyNewTopics(newTopics);
      }
    } catch (e) {
      // Handle error
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 檢查並通知新課程（學生端）
  Future<void> _checkAndNotifyNewTopics(List<GrammarTopicModel> newTopics) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifiedTopicIds = prefs.getStringList('notified_topic_ids') ?? [];
      
      for (var topic in newTopics) {
        // 如果這個課程還沒有通知過
        if (!notifiedTopicIds.contains(topic.id)) {
          final notificationService = NotificationService();
          // 使用 topic.id 的 hash code 確保 ID 在 32 位整數範圍內
          final notificationId = (topic.id.hashCode % 2147483647).abs();
          await notificationService.showNotification(
            id: notificationId,
            title: '新課程上線',
            body: '老師已建立新課程「${topic.title}」，快來查看吧！',
          );
          
          // 記錄已通知的課程 ID
          notifiedTopicIds.add(topic.id);
        }
      }
      
      // 保存已通知的課程 ID 列表
      await prefs.setStringList('notified_topic_ids', notifiedTopicIds);
    } catch (e) {
      print('檢查新課程通知失敗: $e');
      // 不影響載入流程，只記錄錯誤
    }
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
    
    // 注意：通知會在學生端載入課程時自動顯示
    // 不需要在老師端發送通知，因為本地通知只能在發送設備上顯示
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

