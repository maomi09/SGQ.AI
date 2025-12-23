import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

class ChatProvider with ChangeNotifier {
  // 按課程和題目 ID 存儲對話：Map<grammarTopicId_questionId, List<messages>>
  final Map<String, List<Map<String, Object?>>> _conversations = {};
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = false;
  int? _selectedStage;
  String? _currentQuestionId;
  String? _currentGrammarTopicId;
  String? _currentStudentId;

  List<Map<String, Object?>> get messages {
    if (_currentQuestionId == null || _currentGrammarTopicId == null) {
      return [];
    }
    final key = '${_currentGrammarTopicId}_$_currentQuestionId';
    return _conversations[key] ?? [];
  }

  bool get isLoading => _isLoading;
  int? get selectedStage => _selectedStage;
  String? get currentQuestionId => _currentQuestionId;
  String? get currentGrammarTopicId => _currentGrammarTopicId;
  String? get currentStudentId => _currentStudentId;

  void setCurrentQuestion(String? questionId, String? grammarTopicId, {String? studentId}) {
    _currentQuestionId = questionId;
    _currentGrammarTopicId = grammarTopicId;
    if (studentId != null) {
      _currentStudentId = studentId;
    }
    _selectedStage = null; // 切換題目時重置階段
    notifyListeners();
  }

  Future<void> loadMessages(String questionId, String grammarTopicId, String studentId) async {
    _currentQuestionId = questionId;
    _currentGrammarTopicId = grammarTopicId;
    _currentStudentId = studentId;
    
    final key = '${grammarTopicId}_$questionId';
    final messages = await _supabaseService.loadChatMessages(
      questionId: questionId,
      grammarTopicId: grammarTopicId,
    );
    
    // 轉換為 List<Map<String, Object?>>
    _conversations[key] = messages.map((msg) => Map<String, Object?>.from(msg)).toList();
    
    // 如果有消息，恢復最後一個階段的選中狀態
    if (messages.isNotEmpty) {
      final lastMessage = messages.last;
      if (lastMessage['stage'] != null) {
        _selectedStage = lastMessage['stage'] as int;
      }
    }
    
    notifyListeners();
  }

  Future<void> addMessage(Map<String, dynamic> message) async {
    if (_currentQuestionId == null || _currentGrammarTopicId == null) {
      print('Warning: Cannot add message - questionId or grammarTopicId is null');
      return;
    }
    final key = '${_currentGrammarTopicId}_$_currentQuestionId';
    if (!_conversations.containsKey(key)) {
      _conversations[key] = [];
    }
    
    // 轉換為 Map<String, Object?> 以符合類型要求
    final messageAsObject = Map<String, Object?>.from(message);
    
    print('Adding message: type=${message['type']}, stage=${message['stage']}, content=${(message['content'] as String).substring(0, (message['content'] as String).length > 30 ? 30 : (message['content'] as String).length)}...');
    _conversations[key]!.add(messageAsObject);
    
    // 自動保存到資料庫（如果 studentId 存在）
    if (_currentStudentId != null) {
      try {
        final stage = message['stage'] as int? ?? _selectedStage ?? 1;
        await _supabaseService.saveChatMessage(
          questionId: _currentQuestionId!,
          grammarTopicId: _currentGrammarTopicId!,
          studentId: _currentStudentId!,
          stage: stage,
          messageType: message['type'] as String,
          content: message['content'] as String,
        );
        print('Message saved to database successfully');
      } catch (e) {
        print('Error saving chat message to database: $e');
        // 不拋出異常，確保消息仍然顯示在 UI 上
      }
    } else {
      print('Warning: studentId is null, message will not be saved to database');
    }
    
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setSelectedStage(int? stage) {
    _selectedStage = stage;
    notifyListeners();
  }

  void clearMessages() {
    if (_currentQuestionId == null || _currentGrammarTopicId == null) {
      return;
    }
    final key = '${_currentGrammarTopicId}_$_currentQuestionId';
    _conversations[key]?.clear();
    _selectedStage = null;
    notifyListeners();
  }

  // 清除特定階段的對話
  void clearStageMessages(int stage) {
    if (_currentQuestionId == null || _currentGrammarTopicId == null) {
      return;
    }
    final key = '${_currentGrammarTopicId}_$_currentQuestionId';
    if (_conversations.containsKey(key)) {
      _conversations[key]!.removeWhere((msg) => msg['stage'] == stage);
      notifyListeners();
    }
  }

  // 獲取 _conversations（用於外部訪問）
  Map<String, List<Map<String, Object?>>> get conversations => _conversations;
}

