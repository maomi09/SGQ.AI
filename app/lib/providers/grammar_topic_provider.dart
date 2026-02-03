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
  RealtimeChannel? _questionsChannel;
  RealtimeChannel? _badgesChannel;

  List<GrammarTopicModel> get topics => _topics;
  GrammarTopicModel? get selectedTopic => _selectedTopic;
  bool get isLoading => _isLoading;

  /// 初始化 Realtime 訂閱（學生端使用）
  Future<void> initializeRealtimeSubscription() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 取消現有的訂閱
      _realtimeChannel?.unsubscribe();
      _questionsChannel?.unsubscribe();
      _badgesChannel?.unsubscribe();
      
      // 訂閱 grammar_topics 表的 INSERT 事件（新課程）
      _realtimeChannel = _supabaseClient
          .channel('grammar_topics_changes_$timestamp')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'grammar_topics',
            callback: (payload) async {
              print('收到新課程 Realtime 事件: ${payload.newRecord}');
              await _handleNewTopicRealtime(payload.newRecord);
            },
          )
          .subscribe(
            (status, [error]) {
              if (status == RealtimeSubscribeStatus.subscribed) {
                print('Realtime 訂閱成功：已連接到 grammar_topics 表');
              } else if (status == RealtimeSubscribeStatus.timedOut) {
                print('Realtime 訂閱超時（grammar_topics），嘗試重新訂閱...');
                Future.delayed(const Duration(seconds: 2), () {
                  initializeRealtimeSubscription();
                });
              } else if (status == RealtimeSubscribeStatus.channelError) {
                print('Realtime 訂閱錯誤（grammar_topics）: $error');
                Future.delayed(const Duration(seconds: 2), () {
                  initializeRealtimeSubscription();
                });
              }
            },
          );
      
      // 訂閱 questions 表的 UPDATE 事件（老師評語）
      final currentUserId = _supabaseClient.auth.currentUser?.id;
      if (currentUserId != null) {
        _questionsChannel = _supabaseClient
            .channel('questions_comments_$timestamp')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'questions',
              callback: (payload) async {
                // 只處理當前學生的題目
                final studentId = payload.newRecord['student_id'] as String?;
                if (studentId == currentUserId) {
                  print('收到評語更新 Realtime 事件: ${payload.newRecord}');
                  await _handleCommentUpdateRealtime(payload.newRecord);
                }
              },
            )
            .subscribe(
              (status, [error]) {
                if (status == RealtimeSubscribeStatus.subscribed) {
                  print('Realtime 訂閱成功：已連接到 questions 表（評語）');
                } else if (status == RealtimeSubscribeStatus.timedOut) {
                  print('Realtime 訂閱超時（questions），嘗試重新訂閱...');
                  Future.delayed(const Duration(seconds: 2), () {
                    initializeRealtimeSubscription();
                  });
                } else if (status == RealtimeSubscribeStatus.channelError) {
                  print('Realtime 訂閱錯誤（questions）: $error');
                  Future.delayed(const Duration(seconds: 2), () {
                    initializeRealtimeSubscription();
                  });
                }
              },
            );
        
        // 訂閱 badges 表的 INSERT 事件（獲得徽章）
        _badgesChannel = _supabaseClient
            .channel('badges_changes_$timestamp')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'badges',
              callback: (payload) async {
                // 只處理當前學生的徽章
                final studentId = payload.newRecord['student_id'] as String?;
                if (studentId == currentUserId) {
                  print('收到徽章 Realtime 事件: ${payload.newRecord}');
                  await _handleBadgeRealtime(payload.newRecord);
                }
              },
            )
            .subscribe(
              (status, [error]) {
                if (status == RealtimeSubscribeStatus.subscribed) {
                  print('Realtime 訂閱成功：已連接到 badges 表');
                } else if (status == RealtimeSubscribeStatus.timedOut) {
                  print('Realtime 訂閱超時（badges），嘗試重新訂閱...');
                  Future.delayed(const Duration(seconds: 2), () {
                    initializeRealtimeSubscription();
                  });
                } else if (status == RealtimeSubscribeStatus.channelError) {
                  print('Realtime 訂閱錯誤（badges）: $error');
                  Future.delayed(const Duration(seconds: 2), () {
                    initializeRealtimeSubscription();
                  });
                }
              },
            );
      }
    } catch (e) {
      print('初始化 Realtime 訂閱失敗: $e');
      // 延遲後重試
      Future.delayed(const Duration(seconds: 3), () {
        initializeRealtimeSubscription();
      });
    }
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

  /// 處理評語更新 Realtime 事件
  Future<void> _handleCommentUpdateRealtime(Map<String, dynamic> newRecord) async {
    try {
      final teacherComment = newRecord['teacher_comment'] as String?;
      final questionId = newRecord['id'] as String;
      
      // 只有在有新評語時才發送通知（評語不為空）
      if (teacherComment != null && teacherComment.isNotEmpty) {
        // 檢查是否已經通知過這個評語
        final prefs = await SharedPreferences.getInstance();
        final notifiedCommentIds = prefs.getStringList('notified_comment_ids') ?? [];
        
        // 使用 questionId + 評語更新時間戳來避免重複通知（如果評語被更新多次）
        final commentUpdatedAt = newRecord['teacher_comment_updated_at'] as String? ?? '';
        final notificationKey = '$questionId:$commentUpdatedAt';
        
        if (!notifiedCommentIds.contains(notificationKey)) {
          final notificationService = NotificationService();
          final notificationId = (questionId.hashCode % 2147483647).abs();
          await notificationService.showNotification(
            id: notificationId,
            title: '老師給予評語',
            body: '老師已為您的題目添加評語，快來查看吧！',
          );
          
          // 記錄已通知的評語（使用 questionId + 時間戳作為 key）
          notifiedCommentIds.add(notificationKey);
          // 只保留最近 100 個通知記錄，避免列表過大
          if (notifiedCommentIds.length > 100) {
            notifiedCommentIds.removeRange(0, notifiedCommentIds.length - 100);
          }
          await prefs.setStringList('notified_comment_ids', notifiedCommentIds);
        }
      }
    } catch (e) {
      print('處理評語更新 Realtime 事件失敗: $e');
    }
  }

  /// 處理徽章 Realtime 事件
  Future<void> _handleBadgeRealtime(Map<String, dynamic> newRecord) async {
    try {
      final badgeId = newRecord['id'] as String;
      final badgeName = newRecord['badge_name'] as String? ?? '徽章';
      final badgeType = newRecord['badge_type'] as String? ?? '';
      
      // 檢查是否已經通知過這個徽章
      final prefs = await SharedPreferences.getInstance();
      final notifiedBadgeIds = prefs.getStringList('notified_badge_ids') ?? [];
      
      if (!notifiedBadgeIds.contains(badgeId)) {
        final notificationService = NotificationService();
        final notificationId = (badgeId.hashCode % 2147483647).abs();
        
        // 根據徽章類型顯示不同的訊息
        String title = '獲得徽章';
        String body = '恭喜您獲得$badgeName徽章！';
        
        if (badgeType.contains('bronze')) {
          body = '恭喜您獲得銅牌徽章！';
        } else if (badgeType.contains('silver')) {
          body = '恭喜您獲得銀牌徽章！';
        } else if (badgeType.contains('gold')) {
          body = '恭喜您獲得金牌徽章！';
        }
        
        await notificationService.showNotification(
          id: notificationId,
          title: title,
          body: body,
        );
        
        // 記錄已通知的徽章 ID
        notifiedBadgeIds.add(badgeId);
        await prefs.setStringList('notified_badge_ids', notifiedBadgeIds);
      }
    } catch (e) {
      print('處理徽章 Realtime 事件失敗: $e');
    }
  }

  /// 取消 Realtime 訂閱
  void disposeRealtimeSubscription() {
    _realtimeChannel?.unsubscribe();
    _questionsChannel?.unsubscribe();
    _badgesChannel?.unsubscribe();
    _realtimeChannel = null;
    _questionsChannel = null;
    _badgesChannel = null;
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

