import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/question_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ai_chat_settings_provider.dart';
import '../../services/chatgpt_service.dart';
import '../../widgets/adaptive_app_dialog.dart';
import '../../widgets/ai_assistant_icon.dart';
import '../../widgets/ai_chat_pastel_background.dart';
import '../../services/supabase_service.dart';
import '../../models/question_model.dart';
import '../../utils/error_handler.dart';
import '../privacy_policy_screen.dart';

class ChatGPTChatScreen extends StatefulWidget {
  const ChatGPTChatScreen({super.key});

  @override
  State<ChatGPTChatScreen> createState() => _ChatGPTChatScreenState();
}

class _ChatGPTChatScreenState extends State<ChatGPTChatScreen> {
  /// 底部輸入列佔用高度（含上下留白），供訊息列表避開重疊。
  static const double _messageInputBarExtent = 72;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseService _supabaseService = SupabaseService();
  QuestionModel? _currentQuestion;
  Map<int, DateTime> _completedStages = {};
  bool _isLoadingStages = false;
  bool _showQuestionSelector = true; // 是否顯示題目選擇器
  bool _isStageSelectorExpanded = true; // 階段選擇器是否展開
  Set<String> _shownInfoDialogForQuestions = {}; // 記錄已顯示過提示的題目 ID
  bool _isClosingForDisabledAi = false;
  bool _isAiDisabledDialogShowing = false;

  bool _hasCheckedQuestion = false;
  bool _hasCheckedDataSharingConsent = false;
  /// 各階段已顯示過的訊息數，用於僅對新訊息播放氣泡動畫。
  final Map<int, int> _seenMessageCountByStage = {};
  
  @override
  void initState() {
    super.initState();
    _loadShownInfoDialogQuestions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 同次 App 生命週期內再次開啟：先隱藏題目列表，避免閃一下再切回聊天
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (chatProvider.currentQuestionId != null) {
        setState(() => _showQuestionSelector = false);
      }
      if (!_hasCheckedQuestion) {
        _hasCheckedQuestion = true;
        _checkDataSharingConsent();
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

  // 檢查數據共享許可
  Future<void> _checkDataSharingConsent() async {
    if (_hasCheckedDataSharingConsent) return;
    _hasCheckedDataSharingConsent = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasConsented = prefs.getBool('chatgpt_data_sharing_consent') ?? false;
      
      if (!hasConsented && mounted) {
        _showDataSharingConsentDialog();
      } else {
        _checkIfQuestionSelected();
      }
    } catch (e) {
      print('Error checking data sharing consent: $e');
      // 如果檢查失敗，繼續正常流程
      _checkIfQuestionSelected();
    }
  }

  // 顯示數據共享許可對話框
  void _showDataSharingConsentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.privacy_tip, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(child: Text('數據共享許可')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '為了提供 ChatGPT AI 輔助功能，我們需要將以下資料傳送給 OpenAI（ChatGPT 服務提供者）：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  '共享的資料類型：',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('• 您創建的題目內容（包括題目文字、選項、正確答案）'),
                const Text('• 您與 AI 的對話歷史記錄'),
                const Text('• 題目的文法主題資訊'),
                const Text('• 當前學習階段資訊'),
                const SizedBox(height: 16),
                const Text(
                  '資料接收方：',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('• OpenAI（ChatGPT 服務提供者）'),
                const Text('• 隱私權政策：https://openai.com/policies/privacy-policy'),
                const SizedBox(height: 16),
                const Text(
                  '資料用途：',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('• 提供個人化的 AI 學習輔助和建議'),
                const Text('• 協助您改進題目設計'),
                const Text('• 提供階段性的學習引導'),
                const SizedBox(height: 16),
                const Text(
                  '重要說明：',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• 我們不會將您的資料用於廣告目的',
                  style: TextStyle(color: Colors.orange),
                ),
                const Text(
                  '• 您可以在應用程式設定中隨時撤回同意',
                  style: TextStyle(color: Colors.orange),
                ),
                const Text(
                  '• 如果您不同意共享資料，將無法使用 ChatGPT AI 輔助功能',
                  style: TextStyle(color: Colors.orange),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    ).then((_) {
                      // 返回後再次顯示許可對話框
                      if (mounted) {
                        _showDataSharingConsentDialog();
                      }
                    });
                  },
                  child: const Text(
                    '查看完整隱私權政策',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // 用戶不同意，關閉對話框並返回
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('您需要同意數據共享才能使用 ChatGPT AI 輔助功能'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              child: const Text('不同意'),
            ),
            ElevatedButton(
              onPressed: () async {
                // 用戶同意，保存許可並繼續
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('chatgpt_data_sharing_consent', true);
                  if (mounted) {
                    Navigator.pop(context);
                    _checkIfQuestionSelected();
                  }
                } catch (e) {
                  print('Error saving consent: $e');
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('保存許可失敗，請重試'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('同意並繼續'),
            ),
          ],
        );
      },
    );
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentId = authProvider.currentUser?.id;
    if (studentId != null) {
      await questionProvider.loadQuestions(studentId);
      if (mounted) setState(() {});
    }
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
    
    print('chatProvider.currentQuestionId: ${chatProvider.currentQuestionId}');
    print('studentId: $studentId');
    
    // 只有在 ChatProvider 中已經有選中的題目時才自動載入
    // 不要自動選擇第一個題目
    if (chatProvider.currentQuestionId != null && studentId != null) {
      try {
        final selectedQuestion = questions.firstWhere(
          (q) => q.id == chatProvider.currentQuestionId,
        );
        print('Found previously selected question: ${selectedQuestion.id}');
        await _restoreLastSession(selectedQuestion, studentId);
      } catch (e) {
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

  /// 再次開啟聊天室時還原題目與對話（不重置已選階段）。
  Future<void> _restoreLastSession(
    QuestionModel question,
    String studentId,
  ) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await chatProvider.loadMessages(
      question.id,
      question.grammarTopicId,
      studentId,
    );
    if (!mounted) return;
    setState(() {
      _currentQuestion = question;
      _showQuestionSelector = false;
    });
    await _loadCompletedStages();
    _syncAllStageMessageCounts(
      Provider.of<ChatProvider>(context, listen: false),
    );
  }

  void _syncAllStageMessageCounts(ChatProvider chatProvider) {
    _seenMessageCountByStage.clear();
    for (final msg in chatProvider.messages) {
      final stage = msg['stage'] as int?;
      if (stage == null) continue;
      _seenMessageCountByStage[stage] =
          (_seenMessageCountByStage[stage] ?? 0) + 1;
    }
  }

  int _stageMessageCount(ChatProvider chatProvider, int stage) {
    return chatProvider.messages.where((m) => m['stage'] == stage).length;
  }

  void _scheduleMarkStageMessagesSeen(int stage, int count) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final seen = _seenMessageCountByStage[stage] ?? 0;
      if (count > seen) {
        setState(() => _seenMessageCountByStage[stage] = count);
      }
    });
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: AiChatTheme.accent,
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(12),
          ),
        ),
      ),
    );
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
    _syncAllStageMessageCounts(chatProvider);

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
    _seenMessageCountByStage[stage] = _stageMessageCount(chatProvider, stage);
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
      _seenMessageCountByStage[stage] = 0;
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

    // 重新載入最新的題目資料，確保使用修改後的題目和答案
    print('Reloading question data to get latest updates...');
    final questionProvider = Provider.of<QuestionProvider>(context, listen: false);
    try {
      await questionProvider.loadQuestions(
        _currentQuestion!.studentId,
        grammarTopicId: _currentQuestion!.grammarTopicId,
      );
      
      // 從 QuestionProvider 獲取最新的題目
      final updatedQuestion = questionProvider.questions.firstWhere(
        (q) => q.id == _currentQuestion!.id,
        orElse: () => _currentQuestion!,
      );
      
      // 更新 _currentQuestion 為最新資料
      setState(() {
        _currentQuestion = updatedQuestion;
      });
      print('Question data reloaded: question="${_currentQuestion!.question.substring(0, _currentQuestion!.question.length > 50 ? 50 : _currentQuestion!.question.length)}..."');
    } catch (e) {
      print('Error reloading question data: $e');
      // 如果載入失敗，繼續使用現有的 _currentQuestion
    }

    if (_currentQuestion!.question.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('題目內容為空，請先在出題區填寫題目後再送出')),
        );
      }
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
        _currentQuestion!,
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
    FocusScope.of(context).unfocus();

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
        _currentQuestion!,
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

  Future<void> _showEditCurrentQuestionDialog() async {
    if (_currentQuestion == null) return;

    final questionController = TextEditingController(text: _currentQuestion!.question);
    final explanationController = TextEditingController(
      text: _currentQuestion!.explanation ?? '',
    );
    final optionAController = TextEditingController(
      text: _currentQuestion!.options != null && _currentQuestion!.options!.isNotEmpty
          ? _currentQuestion!.options![0]
          : '',
    );
    final optionBController = TextEditingController(
      text: _currentQuestion!.options != null && _currentQuestion!.options!.length > 1
          ? _currentQuestion!.options![1]
          : '',
    );
    final optionCController = TextEditingController(
      text: _currentQuestion!.options != null && _currentQuestion!.options!.length > 2
          ? _currentQuestion!.options![2]
          : '',
    );
    final optionDController = TextEditingController(
      text: _currentQuestion!.options != null && _currentQuestion!.options!.length > 3
          ? _currentQuestion!.options![3]
          : '',
    );
    final correctAnswerController = TextEditingController(
      text: _currentQuestion!.correctAnswer ?? '',
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('修改目前題目'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: questionController,
                    decoration: const InputDecoration(
                      labelText: '題目內容',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 3,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 12),
                  if (_currentQuestion!.type == QuestionType.multipleChoice) ...[
                    TextField(
                      controller: optionAController,
                      decoration: const InputDecoration(
                        labelText: '選項 A',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: optionBController,
                      decoration: const InputDecoration(
                        labelText: '選項 B',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: optionCController,
                      decoration: const InputDecoration(
                        labelText: '選項 C',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: optionDController,
                      decoration: const InputDecoration(
                        labelText: '選項 D',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: correctAnswerController,
                    decoration: const InputDecoration(
                      labelText: '正確答案',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: explanationController,
                    decoration: const InputDecoration(
                      labelText: '解釋',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) return;

    final questionText = questionController.text.trim();
    final explanationText = explanationController.text.trim();
    final answerText = correctAnswerController.text.trim();
    if (questionText.isEmpty || answerText.isEmpty || explanationText.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('題目、答案、解釋不可為空')),
      );
      return;
    }

    final updates = <String, dynamic>{
      'question': questionText,
      'correct_answer': answerText,
      'explanation': explanationText,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (_currentQuestion!.type == QuestionType.multipleChoice) {
      final options = [
        optionAController.text.trim(),
        optionBController.text.trim(),
        optionCController.text.trim(),
        optionDController.text.trim(),
      ];
      if (options.any((o) => o.isEmpty)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('選擇題四個選項都要填寫')),
        );
        return;
      }
      updates['options'] = options;
    }

    try {
      await _supabaseService.updateQuestion(_currentQuestion!.id, updates);
      final questionProvider = Provider.of<QuestionProvider>(context, listen: false);
      await questionProvider.loadQuestions(
        _currentQuestion!.studentId,
        grammarTopicId: _currentQuestion!.grammarTopicId,
      );
      final refreshed = questionProvider.questions.firstWhere(
        (q) => q.id == _currentQuestion!.id,
        orElse: () => _currentQuestion!,
      );
      if (!mounted) return;
      setState(() {
        _currentQuestion = refreshed;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('題目已更新，後續對話會使用新版內容')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getSafeErrorMessage(e)), backgroundColor: Colors.red),
      );
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
    return Consumer2<ChatProvider, AiChatSettingsProvider>(
      builder: (context, chatProvider, aiSettings, child) {
        if (!aiSettings.isEnabled && !_isClosingForDisabledAi) {
          _isClosingForDisabledAi = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAiDisabledDialogAndClose();
          });
        }

        final questionProvider = Provider.of<QuestionProvider>(context, listen: false);
        final questions = questionProvider.questions;
        final isRestoringQuestion = !_showQuestionSelector &&
            _currentQuestion == null &&
            chatProvider.currentQuestionId != null;
        final viewBottom = MediaQuery.viewInsetsOf(context).bottom;
        final showInputBar =
            !_showQuestionSelector && chatProvider.selectedStage != null;
        final listBottomPadding = showInputBar
            ? 16 + _messageInputBarExtent + viewBottom
            : 16.0;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const AiChatPastelBackground(),
              SafeArea(
                bottom: false,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  fit: StackFit.expand,
                  children: [
                    Column(
                  children: [
              // 標題欄
              AiChatTheme.glassPanel(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                showBottomDivider: true,
                child: Row(
                  children: [
                    const AiAssistantIcon(size: 28),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'AI 小幫手',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AiChatTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline, color: AiChatTheme.textSecondary),
                      tooltip: '階段說明',
                      onPressed: () => _showStageInfoDialog(context),
                    ),
                    if (_currentQuestion != null)
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: AiChatTheme.textSecondary),
                        tooltip: '修改當前題目',
                        onPressed: _showEditCurrentQuestionDialog,
                      ),
                    if (_currentQuestion != null)
                      IconButton(
                        icon: const Icon(Icons.list_alt, color: AiChatTheme.textSecondary),
                        tooltip: '顯示題目清單',
                        onPressed: () {
                          setState(() {
                            _showQuestionSelector = true;
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AiChatTheme.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // 題目選擇器
              if (_showQuestionSelector)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '請選擇題目',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AiChatTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (questions.isEmpty)
                          const Expanded(
                            child: Center(
                              child: Text(
                                '尚未建立任何題目',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                            itemCount: questions.length,
                            itemBuilder: (context, index) {
                              final question = questions[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: AiChatTheme.questionCardDecoration(),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: Text(
                                    question.question.length > 50
                                        ? '${question.question.substring(0, 50)}...'
                                        : question.question,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AiChatTheme.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '階段 ${question.stage}',
                                    style: const TextStyle(
                                      color: AiChatTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: AiChatTheme.textSecondary,
                                  ),
                                  onTap: () => _selectQuestion(question),
                                ),
                              );
                            },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              // 階段選擇（可縮放）
              if (!_showQuestionSelector && _currentQuestion != null)
                AiChatTheme.glassPanel(
                  showBottomDivider: true,
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
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AiChatTheme.textPrimary,
                                ),
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
                                      color: AiChatTheme.accent,
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
                    child: isRestoringQuestion
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AiChatTheme.accent,
                            ),
                          )
                        : _currentQuestion == null
                        ? const Center(
                            child: Text(
                              '請選擇一個題目',
                              style: TextStyle(color: AiChatTheme.textSecondary),
                            ),
                          )
                        : chatProvider.selectedStage == null
                            ? const Center(
                                child: Text(
                                  '請選擇一個階段開始',
                                  style: TextStyle(color: AiChatTheme.textSecondary),
                                ),
                              )
                            : Builder(
                                builder: (context) {
                                  // 過濾出當前階段的消息
                                  final currentStageMessages = chatProvider.messages
                                      .where((msg) => msg['stage'] == chatProvider.selectedStage)
                                      .toList();
                                  
                                  final stage = chatProvider.selectedStage!;
                                  final seenCount =
                                      _seenMessageCountByStage[stage] ?? 0;
                                  if (currentStageMessages.length > seenCount) {
                                    _scheduleMarkStageMessagesSeen(
                                      stage,
                                      currentStageMessages.length,
                                    );
                                  }

                                  if (currentStageMessages.isEmpty && !chatProvider.isLoading) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              '該階段尚未開始對話',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: AiChatTheme.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              '可先點上方「修改當前題目」微調內容，再送出階段提示。\n若不知道怎麼問，可直接輸入：請用繁體中文給我一個簡單示例。',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AiChatTheme.textSecondary,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  return ListView.builder(
                                    controller: _scrollController,
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      listBottomPadding,
                                    ),
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

                                    return _AnimatedChatBubble(
                                      key: ValueKey('chat_${stage}_$index'),
                                      animate: index >= seenCount,
                                      alignment: isSystem
                                          ? Alignment.center
                                          : (isUser
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft),
                                      isUser: isUser,
                                      isSystem: isSystem,
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.78,
                                      content: message['content'] as String,
                                    );
                                  },
                                );
                              },
                            ),
                  ),
                ),
                  ],
                ),
                    if (showInputBar)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: viewBottom,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (!_completedStages
                                      .containsKey(chatProvider.selectedStage) &&
                                  !_isLoadingStages) ...[
                                _buildCircleActionButton(
                                  icon: Icons.check_circle_outline,
                                  tooltip:
                                      '完成階段 ${chatProvider.selectedStage}',
                                  onPressed: () => _completeStage(
                                    chatProvider.selectedStage!,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  style: const TextStyle(
                                    color: AiChatTheme.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '輸入您的問題...',
                                    hintStyle:
                                        TextStyle(color: Colors.grey.shade400),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AiChatTheme.radiusPill,
                                      ),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AiChatTheme.radiusPill,
                                      ),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AiChatTheme.radiusPill,
                                      ),
                                      borderSide: BorderSide(
                                        color: AiChatTheme.accent
                                            .withValues(alpha: 0.35),
                                        width: 1.5,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  maxLines: null,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _sendAdditionalMessage(),
                                  scrollPadding: EdgeInsets.zero,
                                  onTap: () {
                                    Future.delayed(
                                      const Duration(milliseconds: 300),
                                      _scrollToBottom,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildCircleActionButton(
                                icon: Icons.arrow_upward_rounded,
                                tooltip: '送出',
                                onPressed: chatProvider.isLoading
                                    ? null
                                    : _sendAdditionalMessage,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
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
              ? const Color(0xFFD4EDDA)
              : (isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.45)),
          foregroundColor: isCompleted
              ? const Color(0xFF2E7D4F)
              : (isSelected ? AiChatTheme.accent : AiChatTheme.textPrimary),
          elevation: isSelected ? 2 : 0,
          shadowColor: Colors.black.withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AiChatTheme.radiusPill),
            side: BorderSide(
              color: isSelected
                  ? AiChatTheme.accentSoft.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.85),
            ),
          ),
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

  Future<void> _showAiDisabledDialogAndClose() async {
    if (!mounted || _isAiDisabledDialogShowing) return;
    _isAiDisabledDialogShowing = true;
    await AdaptiveAppDialog.showNotify(
      context: context,
      title: 'AI 功能目前已關閉',
      message: '老師已關閉 AI 小幫手，聊天室將自動關閉。',
      iconSfSymbol: 'sparkles.slash',
      confirmLabel: '知道了',
    );
    _isAiDisabledDialogShowing = false;
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

// 三個點點跳動的思考動畫
/// 新訊息氣泡彈出動畫（僅 [animate] 為 true 時播放）。
class _AnimatedChatBubble extends StatefulWidget {
  const _AnimatedChatBubble({
    super.key,
    required this.animate,
    required this.alignment,
    required this.isUser,
    required this.isSystem,
    required this.maxWidth,
    required this.content,
  });

  final bool animate;
  final Alignment alignment;
  final bool isUser;
  final bool isSystem;
  final double maxWidth;
  final String content;

  @override
  State<_AnimatedChatBubble> createState() => _AnimatedChatBubbleState();
}

class _AnimatedChatBubbleState extends State<_AnimatedChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _scale = Tween<double>(begin: 0.68, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.7, curve: Curves.easeOut),
      ),
    );
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaleAlignment = widget.isUser
        ? Alignment.centerRight
        : (widget.isSystem ? Alignment.center : Alignment.centerLeft);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            alignment: scaleAlignment,
            child: child,
          ),
        );
      },
      child: Align(
        alignment: widget.alignment,
        child: AiChatTheme.messageBubble(
          isUser: widget.isUser,
          isSystem: widget.isSystem,
          maxWidth: widget.maxWidth,
          child: Text(
            widget.content,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AiChatTheme.textPrimary,
              fontStyle:
                  widget.isSystem ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ),
    );
  }
}

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
                      decoration: const BoxDecoration(
                        color: AiChatTheme.accentSoft,
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
            color: AiChatTheme.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// 彈出式聊天對話框（須先確認 AI 已開啟）
void showChatDialog(BuildContext context) {
  final aiSettings =
      Provider.of<AiChatSettingsProvider>(context, listen: false);
  if (!aiSettings.isEnabled) {
    AdaptiveAppDialog.showNotify(
      context: context,
      title: 'AI 功能目前已關閉',
      message: '老師已關閉 AI 小幫手，目前無法使用。',
      iconSfSymbol: 'sparkles.slash',
    );
    return;
  }
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
        return const ChatGPTChatScreen();
      },
    ),
  );
}
