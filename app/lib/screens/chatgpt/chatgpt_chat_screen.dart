import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/question_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/chatgpt_service.dart';
import '../../services/supabase_service.dart';
import '../../models/question_model.dart';
import '../../utils/error_handler.dart';

class ChatGPTChatScreen extends StatefulWidget {
  const ChatGPTChatScreen({super.key});

  @override
  State<ChatGPTChatScreen> createState() => _ChatGPTChatScreenState();
}

class _ChatGPTChatScreenState extends State<ChatGPTChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseService _supabaseService = SupabaseService();
  QuestionModel? _currentQuestion;
  Map<int, DateTime> _completedStages = {};
  bool _isLoadingStages = false;
  bool _showQuestionSelector = true; // 是否顯示題目選擇器
  bool _isStageSelectorExpanded = true; // 階段選擇器是否展開
  Set<String> _shownInfoDialogForQuestions = {}; // 記錄已顯示過提示的題目 ID

  bool _hasCheckedQuestion = false;
  
  @override
  void initState() {
    super.initState();
    _loadShownInfoDialogQuestions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasCheckedQuestion) {
        _hasCheckedQuestion = true;
        _checkIfQuestionSelected();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 從 SharedPreferences 載入已顯示過提示的題目列表
  Future<void> _loadShownInfoDialogQuestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final questionIds = prefs.getStringList('ai_helper_shown_info_question_ids') ?? [];
      setState(() {
        _shownInfoDialogForQuestions = questionIds.toSet();
      });
    } catch (e) {
      print('Error loading shown info dialog questions: $e');
    }
  }

  // 保存已顯示過提示的題目 ID 到 SharedPreferences
  Future<void> _saveShownInfoDialogQuestion(String questionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final questionIds = prefs.getStringList('ai_helper_shown_info_question_ids') ?? [];
      if (!questionIds.contains(questionId)) {
        questionIds.add(questionId);
        await prefs.setStringList('ai_helper_shown_info_question_ids', questionIds);
      }
    } catch (e) {
      print('Error saving shown info dialog question: $e');
    }
  }

  void _showStageInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('階段說明'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStageInfoItem(
                  stage: 1,
                  title: '階段一: Cognitive',
                  description: '這個階段可以幫助您深入思考題目的設計邏輯。AI 會引導您反思題目是否清楚地聚焦在特定的文法規則上，以及題目的結構是否會讓學習者感到困惑。透過這個階段的協助，您可以更清楚地了解自己題目的核心目標。',
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildStageInfoItem(
                  stage: 2,
                  title: '階段二: Form-focused',
                  description: '這個階段專注於幫助您檢視題目中的文法形式。AI 會協助您識別題目涉及的重要文法結構（如時態、語序、語態等），並指出哪些部分可能對學習者最具挑戰性。這能幫助您確保題目在文法形式上更加精確。',
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                _buildStageInfoItem(
                  stage: 3,
                  title: '階段三: Linguistic',
                  description: '這個階段協助您改善題目的語言表達。AI 會評估您的措辭是否自然、清晰，並適合EFL學習者理解。透過這個階段的指導，您可以讓題目的語言更加流暢易懂，同時保持原本要測試的文法重點。',
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                _buildStageInfoItem(
                  stage: 4,
                  title: '階段四: Metacognitive',
                  description: '這個階段幫助您全面評估題目的整體品質。AI 會協助您分析題目的優缺點，判斷題目是否適合目標程度的學習者，並提供改進建議。透過這個階段的反思，您可以學習如何創建更好的文法題目。',
                  color: Colors.purple,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('我知道了'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStageInfoItem({
    required int stage,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$stage',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color is MaterialColor ? color.shade700 : color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkIfQuestionSelected() async {
    print('_checkIfQuestionSelected called');
    
    final questionProvider = Provider.of<QuestionProvider>(context, listen: false);
    final questions = questionProvider.questions;
    
    print('Questions count: ${questions.length}');
    
    if (questions.isEmpty) {
      print('No questions, showing selector');
      setState(() {
        _showQuestionSelector = true;
        _currentQuestion = null;
      });
      return;
    }
    
    // 檢查是否有已選中的題目（從 ChatProvider）
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentId = authProvider.currentUser?.id;
    
    print('chatProvider.currentQuestionId: ${chatProvider.currentQuestionId}');
    print('studentId: $studentId');
    
    // 只有在 ChatProvider 中已經有選中的題目時才自動載入
    // 不要自動選擇第一個題目
    if (chatProvider.currentQuestionId != null && studentId != null) {
      // 嘗試找到對應的題目
      try {
        final selectedQuestion = questions.firstWhere(
          (q) => q.id == chatProvider.currentQuestionId,
        );
        print('Found previously selected question: ${selectedQuestion.id}');
        // 載入之前的對話
        await chatProvider.loadMessages(selectedQuestion.id, selectedQuestion.grammarTopicId, studentId);
        await _selectQuestion(selectedQuestion);
      } catch (e) {
        // 如果找不到對應的題目，顯示選擇器
        print('Previously selected question not found, showing selector');
        setState(() {
          _showQuestionSelector = true;
          _currentQuestion = null;
        });
      }
    } else {
      // 沒有選中的題目，顯示選擇器
      print('No previously selected question, showing selector');
      setState(() {
        _showQuestionSelector = true;
        _currentQuestion = null;
      });
    }
  }

  Future<void> _selectQuestion(QuestionModel question) async {
    print('_selectQuestion called for question: ${question.id}');
    
    // 檢查是否為第一次選擇這個題目
    final isFirstTime = !_shownInfoDialogForQuestions.contains(question.id);
    if (isFirstTime) {
      _shownInfoDialogForQuestions.add(question.id);
      // 保存到 SharedPreferences
      await _saveShownInfoDialogQuestion(question.id);
    }
    
    setState(() {
      _currentQuestion = question;
      _showQuestionSelector = false;
    });
    
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentId = authProvider.currentUser?.id;
    
    print('studentId: $studentId');
    
    if (studentId != null) {
      chatProvider.setCurrentQuestion(question.id, question.grammarTopicId, studentId: studentId);
      // 載入之前的對話
      print('Loading messages for question ${question.id}...');
      await chatProvider.loadMessages(question.id, question.grammarTopicId, studentId);
      print('Messages loaded: ${chatProvider.messages.length} messages');
    } else {
      print('Warning: studentId is null, setting current question without studentId');
      chatProvider.setCurrentQuestion(question.id, question.grammarTopicId);
    }
    
    await _loadCompletedStages();
    
    // 如果是第一次選擇這個題目，在 UI 更新後顯示提示對話框
    if (isFirstTime) {
      // 使用 addPostFrameCallback 確保在 UI 更新後再顯示對話框
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentQuestion?.id == question.id) {
          _showStageInfoDialog(context);
        }
      });
    }
    
    print('_selectQuestion completed');
  }

  Future<void> _loadCompletedStages() async {
    if (_currentQuestion == null) return;
    
    setState(() {
      _isLoadingStages = true;
    });

    try {
      final completed = await _supabaseService.getCompletedStages(_currentQuestion!.id);
      setState(() {
        _completedStages = completed;
        _isLoadingStages = false;
      });
    } catch (e) {
      print('Error loading completed stages: $e');
      setState(() {
        _isLoadingStages = false;
      });
    }
  }

  Future<void> _completeStage(int stage) async {
    if (_currentQuestion == null) return;

    setState(() {
      _isLoadingStages = true;
    });

    try {
      await _supabaseService.completeStage(_currentQuestion!.id, stage);
      await _loadCompletedStages();
      
      // 重新載入題目以更新狀態
      final questionProvider = Provider.of<QuestionProvider>(context, listen: false);
      await questionProvider.loadQuestions(
        _currentQuestion!.studentId,
        grammarTopicId: _currentQuestion!.grammarTopicId,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('階段 $stage 已完成！'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getSafeErrorMessage(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStages = false;
        });
      }
    }
  }

  bool _canAccessStage(int stage) {
    if (stage == 1) return true;
    return _completedStages.containsKey(stage - 1);
  }

  // 檢查該階段是否已經發送過 prompt
  bool _hasStagePromptBeenSent(int stage, ChatProvider chatProvider) {
    // 檢查 messages 中是否有該階段的初始 prompt（type 為 'user' 且 content 為 '階段 X'）
    print('_hasStagePromptBeenSent: Checking stage $stage');
    print('Current questionId: ${chatProvider.currentQuestionId}, grammarTopicId: ${chatProvider.currentGrammarTopicId}');
    print('Messages count: ${chatProvider.messages.length}');
    
    if (chatProvider.messages.isNotEmpty) {
      print('All messages:');
      for (var msg in chatProvider.messages) {
        final content = msg['content'] as String?;
        final contentPreview = content != null && content.length > 50 ? content.substring(0, 50) : content;
        print('  - type: ${msg['type']}, stage: ${msg['stage']}, content: $contentPreview');
      }
    }
    
    final hasBeenSent = chatProvider.messages.any((msg) {
      final msgStage = msg['stage'] as int?;
      final msgType = msg['type'] as String?;
      final msgContent = msg['content'] as String?;
      final matches = msgStage == stage &&
          msgType == 'user' &&
          msgContent == '階段 $stage';
      if (matches) {
        print('Found matching message: stage=$msgStage, type=$msgType, content=$msgContent');
      }
      return matches;
    });
    
    print('_hasStagePromptBeenSent result: $hasBeenSent');
    return hasBeenSent;
  }

  // 切換階段但不發送 prompt
  Future<void> _switchToStage(int stage) async {
    if (_currentQuestion == null) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // 更新題目的 stage 欄位
    try {
      await _supabaseService.updateQuestion(_currentQuestion!.id, {
        'stage': stage,
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      // 直接更新本地 _currentQuestion 的 stage，不需要重新載入
      setState(() {
        _currentQuestion = QuestionModel(
          id: _currentQuestion!.id,
          studentId: _currentQuestion!.studentId,
          grammarTopicId: _currentQuestion!.grammarTopicId,
          type: _currentQuestion!.type,
          question: _currentQuestion!.question,
          options: _currentQuestion!.options,
          correctAnswer: _currentQuestion!.correctAnswer,
          explanation: _currentQuestion!.explanation,
          stage: stage,
          completedStages: _currentQuestion!.completedStages,
          createdAt: _currentQuestion!.createdAt,
          updatedAt: DateTime.now(),
        );
      });
    } catch (e) {
      print('Error updating question stage: $e');
    }
    
    chatProvider.setSelectedStage(stage);
    _scrollToBottom();
  }

  // 重新生成該階段的 prompt（清除對話後重新發送）
  Future<void> _regenerateStagePrompt(int stage) async {
    if (_currentQuestion == null) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentId = authProvider.currentUser?.id;

    if (studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法重新生成：用戶未登入')),
      );
      return;
    }

    // 確認對話
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('重新生成對話'),
          content: const Text('這將清除當前階段的對話記錄並重新開始。確定要繼續嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // 清除該階段的對話（從本地和資料庫）
    try {
      // 從資料庫刪除該階段的對話
      await _supabaseService.deleteChatMessages(
        questionId: _currentQuestion!.id,
        grammarTopicId: _currentQuestion!.grammarTopicId,
        stage: stage,
      );

      // 從本地清除該階段的對話
      chatProvider.clearStageMessages(stage);
    } catch (e) {
      print('Error clearing stage messages: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getSafeErrorMessage(e))),
      );
      return;
    }

    // 重新發送 prompt
    await _sendStagePrompt(stage);
  }

  Future<void> _sendStagePrompt(int stage) async {
    print('_sendStagePrompt called for stage $stage');
    
    if (_currentQuestion == null) {
      print('Error: _currentQuestion is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先建立題目')),
      );
      return;
    }

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentId = authProvider.currentUser?.id;
    
    print('studentId: $studentId, currentStudentId: ${chatProvider.currentStudentId}');
    print('Current question: id=${_currentQuestion!.id}, grammarTopicId=${_currentQuestion!.grammarTopicId}');
    print('ChatProvider current: questionId=${chatProvider.currentQuestionId}, grammarTopicId=${chatProvider.currentGrammarTopicId}');
    
    // 確保 ChatProvider 的當前題目設置正確（必須在檢查 _hasStagePromptBeenSent 之前設置）
    if (studentId != null) {
      print('Setting current question with studentId');
      chatProvider.setCurrentQuestion(_currentQuestion!.id, _currentQuestion!.grammarTopicId, studentId: studentId);
    } else {
      print('Warning: studentId is null, setting current question without studentId');
      chatProvider.setCurrentQuestion(_currentQuestion!.id, _currentQuestion!.grammarTopicId);
    }
    
    print('After setting: questionId=${chatProvider.currentQuestionId}, grammarTopicId=${chatProvider.currentGrammarTopicId}, messages count=${chatProvider.messages.length}');
    
    // 檢查該階段是否已經完成
    if (_completedStages.containsKey(stage)) {
      print('Stage $stage is already completed, switching to stage');
      // 如果已經完成，只切換階段，不發送新的 prompt
      await _switchToStage(stage);
      return;
    }
    
    // 檢查該階段是否已經發送過 prompt（只檢查當前題目的消息）
    if (_hasStagePromptBeenSent(stage, chatProvider)) {
      print('Stage $stage prompt already sent for this question, switching to stage');
      // 如果已經發送過，只切換階段，不發送新的 prompt
      await _switchToStage(stage);
      return;
    }
    
    print('Proceeding to send prompt for stage $stage');
    
    // 更新題目的 stage 欄位，表示學生當前正在進行這個階段
    try {
      print('Updating question ${_currentQuestion!.id} stage to $stage');
      await _supabaseService.updateQuestion(_currentQuestion!.id, {
        'stage': stage,
        'updated_at': DateTime.now().toIso8601String(),
      });
      print('Question stage updated successfully');
      
      // 直接更新本地 _currentQuestion 的 stage，不需要重新載入
      setState(() {
        _currentQuestion = QuestionModel(
          id: _currentQuestion!.id,
          studentId: _currentQuestion!.studentId,
          grammarTopicId: _currentQuestion!.grammarTopicId,
          type: _currentQuestion!.type,
          question: _currentQuestion!.question,
          options: _currentQuestion!.options,
          correctAnswer: _currentQuestion!.correctAnswer,
          explanation: _currentQuestion!.explanation,
          stage: stage,
          completedStages: _currentQuestion!.completedStages,
          createdAt: _currentQuestion!.createdAt,
          updatedAt: DateTime.now(),
        );
      });
      print('Local question updated: stage=$stage');
    } catch (e) {
      print('Error updating question stage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getSafeErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    print('Setting selected stage to $stage and loading to true');
    chatProvider.setSelectedStage(stage);
    chatProvider.setLoading(true);
    
    try {
      print('Adding system message...');
      // 先發送題目提示
      await chatProvider.addMessage({
        'type': 'system',
        'content': '題目為: ${_currentQuestion!.question}',
        'stage': stage,
      });
      print('System message added');
      
      print('Adding user message...');
      await chatProvider.addMessage({
        'type': 'user',
        'content': '階段 $stage',
        'stage': stage,
      });
      print('User message added');

      print('Creating ChatGPTService...');
      final chatGPTService = ChatGPTService();

      print('Sending ChatGPT request for stage $stage...');
      final response = await chatGPTService.getScaffoldingResponse(
        _currentQuestion!.question,
        stage,
      );
      print('ChatGPT response received: ${response.substring(0, response.length > 50 ? 50 : response.length)}...');

      print('Adding assistant message...');
      await chatProvider.addMessage({
        'type': 'assistant',
        'content': response,
        'stage': stage,
      });
      print('Assistant message added');
      
      print('Setting loading to false');
      chatProvider.setLoading(false);
      print('Scrolling to bottom...');
      _scrollToBottom();
      print('_sendStagePrompt completed successfully');
    } catch (e, stackTrace) {
      print('Error in _sendStagePrompt: $e');
      print('Stack trace: $stackTrace');
      chatProvider.setLoading(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getSafeErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 發送追加問題
  Future<void> _sendAdditionalMessage() async {
    print('_sendAdditionalMessage called');
    
    if (_currentQuestion == null) {
      print('Error: _currentQuestion is null');
      return;
    }
    
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      print('Message is empty, returning');
      return;
    }

    print('Message: $message');
    
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentStage = chatProvider.selectedStage;
    
    print('Current stage: $currentStage');
    
    if (currentStage == null) {
      print('No stage selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先選擇一個階段')),
      );
      return;
    }

    print('Adding user message...');
    // 添加用戶消息
    await chatProvider.addMessage({
      'type': 'user',
      'content': message,
      'stage': currentStage,
    });
    _messageController.clear();
    print('User message added, clearing controller');

    // 發送給 ChatGPT（這裡需要實現追加問題的邏輯）
    // 由於 ChatGPT API 需要完整的對話歷史，我們需要將所有消息發送過去
    chatProvider.setLoading(true);
    print('Setting loading to true');
    
    try {
      print('Creating ChatGPTService...');
      final chatGPTService = ChatGPTService();

      // 獲取當前階段的對話歷史
      print('Getting conversation history for stage $currentStage...');
      final conversationHistory = chatProvider.messages
          .where((msg) => msg['stage'] == currentStage)
          .toList();
      print('Conversation history: ${conversationHistory.length} messages');

      // 對於追加問題，我們發送用戶的問題和對話歷史
      print('Sending to ChatGPT...');
      final response = await chatGPTService.getAdditionalResponse(
        message,
        _currentQuestion!.question,
        currentStage,
        conversationHistory,
      );
      print('ChatGPT response received: ${response.substring(0, response.length > 50 ? 50 : response.length)}...');

      print('Adding assistant message...');
      await chatProvider.addMessage({
        'type': 'assistant',
        'content': response,
        'stage': currentStage,
      });
      print('Assistant message added');
      
      chatProvider.setLoading(false);
      print('Setting loading to false');
      print('Scrolling to bottom...');
      _scrollToBottom();
      print('_sendAdditionalMessage completed successfully');
    } catch (e, stackTrace) {
      print('Error in _sendAdditionalMessage: $e');
      print('Stack trace: $stackTrace');
      chatProvider.setLoading(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getSafeErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final questionProvider = Provider.of<QuestionProvider>(context, listen: false);
        final questions = questionProvider.questions;
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
              // 標題欄
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      '🤖',
                      style: TextStyle(
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'AI 小幫手',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline),
                      tooltip: '階段說明',
                      onPressed: () => _showStageInfoDialog(context),
                    ),
                    if (_currentQuestion != null)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: '重新選擇題目',
                        onPressed: () {
                          setState(() {
                            _showQuestionSelector = true;
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // 題目選擇器
              if (_showQuestionSelector)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '請選擇題目',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (questions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              '尚未建立任何題目',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: questions.length,
                            itemBuilder: (context, index) {
                              final question = questions[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                    question.question.length > 50
                                        ? '${question.question.substring(0, 50)}...'
                                        : question.question,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    '階段 ${question.stage}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () => _selectQuestion(question),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              // 階段選擇（可縮放）
              if (!_showQuestionSelector && _currentQuestion != null)
                Container(
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isStageSelectorExpanded = !_isStageSelectorExpanded;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              const Text(
                                '選擇階段',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              if (chatProvider.selectedStage != null)
                                TextButton(
                                  onPressed: () => _regenerateStagePrompt(chatProvider.selectedStage!),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    '小幫手沒回應嗎?嘗試重新生成',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              Icon(
                                _isStageSelectorExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isStageSelectorExpanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildStageButton(1, '階段一', chatProvider),
                                  _buildStageButton(2, '階段二', chatProvider),
                                  _buildStageButton(3, '階段三', chatProvider),
                                  _buildStageButton(4, '階段四', chatProvider),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              // 對話列表
              if (!_showQuestionSelector)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // 點擊空白處收回鍵盤
                      FocusScope.of(context).unfocus();
                    },
                    behavior: HitTestBehavior.translucent,
                    child: _currentQuestion == null
                        ? const Center(
                            child: Text('請選擇一個題目'),
                          )
                        : chatProvider.selectedStage == null
                            ? const Center(
                                child: Text('請選擇一個階段開始'),
                              )
                            : Builder(
                                builder: (context) {
                                  // 過濾出當前階段的消息
                                  final currentStageMessages = chatProvider.messages
                                      .where((msg) => msg['stage'] == chatProvider.selectedStage)
                                      .toList();
                                  
                                  if (currentStageMessages.isEmpty && !chatProvider.isLoading) {
                                    return const Center(
                                      child: Text('該階段尚未開始對話'),
                                    );
                                  }
                                  
                                  return ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(16),
                                    itemCount: currentStageMessages.length + (chatProvider.isLoading ? 1 : 0),
                                    itemBuilder: (context, index) {
                                    if (index == currentStageMessages.length) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: _ThinkingAnimation(),
                                        ),
                                      );
                                    }

                                    final message = currentStageMessages[index];
                                    final isUser = message['type'] == 'user';
                                    final isSystem = message['type'] == 'system';

                                    return Align(
                                      alignment: isSystem
                                          ? Alignment.center
                                          : (isUser ? Alignment.centerRight : Alignment.centerLeft),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isSystem
                                              ? Colors.blue.shade50
                                              : (isUser ? Colors.green.shade100 : Colors.grey[200]),
                                          borderRadius: BorderRadius.circular(12),
                                          border: isSystem
                                              ? Border.all(color: Colors.blue.shade200, width: 1)
                                              : null,
                                        ),
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (message['stage'] != null && !isSystem)
                                              Text(
                                                '階段 ${message['stage']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            if (message['stage'] != null && !isSystem)
                                              const SizedBox(height: 4),
                                            Text(
                                              message['content'] as String,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontStyle: isSystem ? FontStyle.italic : FontStyle.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                  ),
                ),
              // 輸入框（當有選中階段時顯示）
              if (!_showQuestionSelector && chatProvider.selectedStage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: '輸入您的問題...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendAdditionalMessage(),
                          scrollPadding: const EdgeInsets.all(20.0),
                          onTap: () {
                            // 當點擊輸入框時，滾動到底部，確保輸入框可見
                            Future.delayed(const Duration(milliseconds: 300), () {
                              _scrollToBottom();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: chatProvider.isLoading 
                            ? null 
                            : () {
                                print('Send button clicked, isLoading: ${chatProvider.isLoading}');
                                _sendAdditionalMessage();
                              },
                        icon: const Icon(Icons.send),
                        color: Colors.green.shade600,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              // 完成階段按鈕
              if (!_showQuestionSelector && 
                  chatProvider.selectedStage != null && 
                  !_completedStages.containsKey(chatProvider.selectedStage) &&
                  !_isLoadingStages)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border(
                      top: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _completeStage(chatProvider.selectedStage!),
                      icon: const Icon(Icons.check_circle),
                      label: Text('完成階段 ${chatProvider.selectedStage}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
            ),
          );
        },
      );
    }

  Widget _buildStageButton(int stage, String label, ChatProvider chatProvider) {
    final isSelected = chatProvider.selectedStage == stage;
    final isCompleted = _completedStages.containsKey(stage);
    final canAccess = _canAccessStage(stage);
    final hasPromptBeenSent = _hasStagePromptBeenSent(stage, chatProvider);
    
    print('_buildStageButton: stage=$stage, isLoading=${chatProvider.isLoading}, canAccess=$canAccess, isSelected=$isSelected, isCompleted=$isCompleted, hasPromptBeenSent=$hasPromptBeenSent');
    
    return Tooltip(
      message: !canAccess 
          ? '請先完成階段 ${stage - 1}' 
          : (isCompleted 
              ? '已完成' 
              : (hasPromptBeenSent ? '已發送過 prompt，點擊切換階段' : '')),
      child: ElevatedButton(
        onPressed: (chatProvider.isLoading || !canAccess) 
            ? null 
            : () {
                print('Stage button $stage clicked - calling _sendStagePrompt');
                _sendStagePrompt(stage);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: isCompleted 
              ? Colors.green.shade300
              : (isSelected ? Colors.green.shade600 : Colors.white),
          foregroundColor: isCompleted || isSelected ? Colors.white : Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
            if (isCompleted) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_circle, size: 14),
            ] else if (hasPromptBeenSent && !isSelected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chat_bubble_outline, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}

// 三個點點跳動的思考動畫
class _ThinkingAnimation extends StatefulWidget {
  const _ThinkingAnimation();

  @override
  State<_ThinkingAnimation> createState() => _ThinkingAnimationState();
}

class _ThinkingAnimationState extends State<_ThinkingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final delay = index * 0.2;
                final animationValue = (_controller.value + delay) % 1.0;
                final offset = (animationValue < 0.5)
                    ? animationValue * 2.0
                    : 2.0 - (animationValue * 2.0);
                final yOffset = offset * 8.0;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Transform.translate(
                    offset: Offset(0, -yOffset),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
        const SizedBox(height: 12),
        Text(
          '小幫手正在思考中~',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// 彈出式聊天對話框
void showChatDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    // iOS 需要啟用這個選項以獲得更好的鍵盤處理
    enableDrag: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        // iOS 和 Android 都使用相同的處理方式
        // MediaQuery.of(context).viewInsets.bottom 在兩個平台上都能正確工作
        return AnimatedPadding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: const ChatGPTChatScreen(),
        );
      },
    ),
  );
}
