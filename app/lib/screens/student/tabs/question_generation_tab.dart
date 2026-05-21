import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/grammar_topic_provider.dart';
import '../../../providers/ai_chat_settings_provider.dart';
import '../../../providers/question_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../models/question_model.dart';
import '../../../widgets/student_tab_top_bar.dart';
import '../../../widgets/adaptive_app_dialog.dart';
import '../../../widgets/student_ai_assistant_button.dart';
class QuestionGenerationTab extends StatefulWidget {
  const QuestionGenerationTab({super.key});

  @override
  State<QuestionGenerationTab> createState() => _QuestionGenerationTabState();
}

class _QuestionGenerationTabState extends State<QuestionGenerationTab> {
  final SupabaseService _supabaseService = SupabaseService();
  final _questionController = TextEditingController();
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _optionCController = TextEditingController();
  final _optionDController = TextEditingController();
  final _correctAnswerController = TextEditingController();
  final _explanationController = TextEditingController();
  QuestionType _selectedType = QuestionType.multipleChoice;
  String? _selectedCorrectAnswer;
  QuestionModel? _editingQuestion;
  bool? _lastAiEnabledState;
  bool _isAiStatusDialogShowing = false;
  bool _isStudentCompletionConfirmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQuestions();
    });
  }


  String? _lastLoadedTopicId;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
    final currentTopicId = grammarTopicProvider.selectedTopic?.id;
    
    // 只有在主題改變時才重新載入，避免無限循環
    if (currentTopicId != null && currentTopicId != _lastLoadedTopicId) {
      _lastLoadedTopicId = currentTopicId;
      // 使用 addPostFrameCallback 避免在 build 階段觸發狀態更新
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadQuestions();
        }
      });
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _optionCController.dispose();
    _optionDController.dispose();
    _correctAnswerController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  Future<void> _onPullRefresh() async {
    final grammarTopicProvider =
        Provider.of<GrammarTopicProvider>(context, listen: false);
    await grammarTopicProvider.loadTopics(
      classId: grammarTopicProvider.currentClassId,
    );
    if (grammarTopicProvider.selectedTopic != null) {
      await _loadQuestions();
    }
  }

  Future<void> _loadQuestions() async {
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
    final questionProvider = Provider.of<QuestionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (grammarTopicProvider.selectedTopic != null && authProvider.currentUser != null) {
      await _syncAiSetting();
      _isStudentCompletionConfirmed = await _supabaseService
          .isStudentAttentionResolved(
            authProvider.currentUser!.id,
            grammarTopicId: grammarTopicProvider.selectedTopic!.id,
          );
      await questionProvider.loadQuestions(
        authProvider.currentUser!.id,
        grammarTopicId: grammarTopicProvider.selectedTopic!.id,
      );
    }
  }

  Future<void> _syncAiSetting() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final classProvider = Provider.of<ClassProvider>(context, listen: false);
    final aiSettings = Provider.of<AiChatSettingsProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null || user.role != 'student') return;
    await aiSettings.refreshForStudent(
      studentId: user.id,
      classId: classProvider.studentClass?.id ?? user.classId,
    );
  }

  Future<void> _showAiHelperStatusDialog(bool isEnabled) async {
    if (!mounted || _isAiStatusDialogShowing) return;
    _isAiStatusDialogShowing = true;
    await AdaptiveAppDialog.showNotify(
      context: context,
      title: isEnabled ? 'AI 小幫手已開啟' : 'AI 小幫手已關閉',
      message: isEnabled
          ? '老師已開啟 AI 小幫手，您現在可以使用。'
          : '老師已關閉 AI 小幫手，暫時無法使用。',
      iconSfSymbol: isEnabled ? 'sparkles' : 'sparkles.slash',
    );
    _isAiStatusDialogShowing = false;
  }

  Future<void> _confirmStudentCompletion() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final grammarTopicProvider =
        Provider.of<GrammarTopicProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null || grammarTopicProvider.selectedTopic == null) return;
    try {
      await _supabaseService.markStudentAttentionResolved(
        user.id,
        grammarTopicId: grammarTopicProvider.selectedTopic!.id,
        reason: 'student_manual_completion',
      );
      if (!mounted) return;
      setState(() {
        _isStudentCompletionConfirmed = true;
      });
      await AdaptiveAppDialog.showNotify(
        context: context,
        title: '已確認完成',
        message: '此課程已送出完成確認，老師端會立即看到您的狀態。',
        iconSfSymbol: 'checkmark.circle.fill',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('送出失敗：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startEditing(QuestionModel question) {
    setState(() {
      _editingQuestion = question;
      _questionController.text = question.question;
      _selectedType = question.type;
      _explanationController.text = question.explanation ?? '';

      if (question.type == QuestionType.multipleChoice) {
        if (question.options != null && question.options!.length >= 4) {
          _optionAController.text = question.options![0];
          _optionBController.text = question.options![1];
          _optionCController.text = question.options![2];
          _optionDController.text = question.options![3];
        }
        _selectedCorrectAnswer = question.correctAnswer;
      } else {
        _correctAnswerController.text = question.correctAnswer ?? '';
      }
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingQuestion = null;
      _questionController.clear();
      _optionAController.clear();
      _optionBController.clear();
      _optionCController.clear();
      _optionDController.clear();
      _correctAnswerController.clear();
      _explanationController.clear();
      _selectedCorrectAnswer = null;
      _selectedType = QuestionType.multipleChoice;
    });
  }

  Future<void> _submitQuestion() async {
    if (_questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('請輸入題目'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (_explanationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('請輸入解釋'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
    final questionProvider = Provider.of<QuestionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (grammarTopicProvider.selectedTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('請先選擇文法主題'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (authProvider.currentUser == null) {
      return;
    }

    List<String>? options;
    String? correctAnswer;

    if (_selectedType == QuestionType.multipleChoice) {
      if (_optionAController.text.isEmpty ||
          _optionBController.text.isEmpty ||
          _optionCController.text.isEmpty ||
          _optionDController.text.isEmpty ||
          _selectedCorrectAnswer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('請填寫所有選項並選擇正確答案'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }
      options = [
        _optionAController.text,
        _optionBController.text,
        _optionCController.text,
        _optionDController.text,
      ];
      correctAnswer = _selectedCorrectAnswer;
    } else {
      if (_correctAnswerController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('請輸入正確答案'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }
      correctAnswer = _correctAnswerController.text;
    }

    if (_editingQuestion != null) {
      // 更新現有題目
      await questionProvider.updateQuestion(_editingQuestion!.id, {
        'question': _questionController.text,
        'type': _selectedType.toString().split('.').last,
        'options': options,
        'correct_answer': correctAnswer,
        'explanation': _explanationController.text.trim(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('題目已更新'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      _cancelEditing();
    } else {
      // 建立新題目（每個文法主題可建立多題，無上限）
      final question = QuestionModel(
        id: '',
        studentId: authProvider.currentUser!.id,
        grammarTopicId: grammarTopicProvider.selectedTopic!.id,
        type: _selectedType,
        question: _questionController.text,
        options: options,
        correctAnswer: correctAnswer,
        explanation: _explanationController.text.trim(),
        stage: 1,
        createdAt: DateTime.now(),
      );

      await questionProvider.createQuestion(question);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('題目已建立'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      _cancelEditing();
    }
    
    await _loadQuestions();
  }

  Future<void> _deleteQuestion(QuestionModel question) async {
    final confirm = await AdaptiveAppDialog.showConfirm(
      context: context,
      title: '確認刪除',
      message: '確定要刪除此題目嗎？',
      confirmLabel: '刪除',
      destructive: true,
    );

    if (confirm == true) {
      final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
      final questionProvider = Provider.of<QuestionProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.currentUser != null) {
        await questionProvider.deleteQuestion(
          question.id,
          authProvider.currentUser!.id,
          grammarTopicId: grammarTopicProvider.selectedTopic?.id,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('題目已刪除'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        
        if (_editingQuestion?.id == question.id) {
          _cancelEditing();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context);
    final questionProvider = Provider.of<QuestionProvider>(context);

    // 獲取當前主題的題目
    final currentQuestions = grammarTopicProvider.selectedTopic != null
        ? questionProvider.questions
            .where((q) => q.grammarTopicId == grammarTopicProvider.selectedTopic!.id)
            .toList()
        : <QuestionModel>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade50,
                Colors.green.shade100,
                Colors.white,
              ],
            ),
          ),
          child: Column(
            children: [
              StudentTabTopBar(
                selectedTopic: grammarTopicProvider.selectedTopic,
                onTopicSelected: (topicId) async {
                  Provider.of<GrammarTopicProvider>(context, listen: false)
                      .selectTopic(topicId);
                  await _loadQuestions();
                },
                trailing: Consumer<AiChatSettingsProvider>(
                  builder: (context, aiSettings, _) {
                    // 僅在伺服器設定載入完成後才建立基準；避免預設 false → 實際 true 誤觸發彈窗
                    if (aiSettings.isLoaded) {
                      if (_lastAiEnabledState == null) {
                        _lastAiEnabledState = aiSettings.isEnabled;
                      } else if (_lastAiEnabledState != aiSettings.isEnabled) {
                        final isEnabled = aiSettings.isEnabled;
                        _lastAiEnabledState = isEnabled;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          _showAiHelperStatusDialog(isEnabled);
                        });
                      }
                    }
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: '新增題目',
                          onPressed: grammarTopicProvider.selectedTopic != null &&
                                  _editingQuestion == null
                              ? () => _showAddQuestionDialog(context)
                              : null,
                        ),
                        IconButton(
                          icon: Icon(
                            _isStudentCompletionConfirmed
                                ? Icons.verified
                                : Icons.task_alt,
                          ),
                          tooltip: _isStudentCompletionConfirmed
                              ? '本課程已確認，可再次更新時間'
                              : '手動確認完成',
                          onPressed: _confirmStudentCompletion,
                        ),
                        const StudentAiAssistantIconButton(),
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onPullRefresh,
                  child: _buildContentScrollView(
                    grammarTopicProvider: grammarTopicProvider,
                    currentQuestions: currentQuestions,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentScrollView({
    required GrammarTopicProvider grammarTopicProvider,
    required List<QuestionModel> currentQuestions,
  }) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 100;

    if (grammarTopicProvider.selectedTopic == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomPadding),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: Center(
              child: Text(
                '請先選擇文法主題',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (currentQuestions.isEmpty && _editingQuestion == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomPadding),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.quiz_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  '尚無題目',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '點擊右上角 + 號新增題目',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding),
      children: [
                              // 編輯表單（如果有正在編輯的題目）
                              if (_editingQuestion != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            '編輯題目',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: _cancelEditing,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: SegmentedButton<QuestionType>(
                                          segments: const [
                                            ButtonSegment(
                                              value: QuestionType.multipleChoice,
                                              label: Text('選擇題'),
                                            ),
                                            ButtonSegment(
                                              value: QuestionType.shortAnswer,
                                              label: Text('問答題'),
                                            ),
                                          ],
                                          selected: {_selectedType},
                                          onSelectionChanged: (Set<QuestionType> newSelection) {
                                            setState(() {
                                              _selectedType = newSelection.first;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildTextField(
                                        controller: _questionController,
                                        label: '題目',
                                        maxLines: 3,
                                      ),
                                      const SizedBox(height: 16),
                                      if (_selectedType == QuestionType.multipleChoice) ...[
                                        _buildTextField(
                                          controller: _optionAController,
                                          label: '選項 A',
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _optionBController,
                                          label: '選項 B',
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _optionCController,
                                          label: '選項 C',
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _optionDController,
                                          label: '選項 D',
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.grey[300]!),
                                          ),
                                          child: DropdownButtonFormField<String>(
                                            value: _selectedCorrectAnswer,
                                            decoration: const InputDecoration(
                                              labelText: '正確答案',
                                              border: InputBorder.none,
                                            ),
                                            items: const [
                                              DropdownMenuItem(value: 'A', child: Text('A')),
                                              DropdownMenuItem(value: 'B', child: Text('B')),
                                              DropdownMenuItem(value: 'C', child: Text('C')),
                                              DropdownMenuItem(value: 'D', child: Text('D')),
                                            ],
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedCorrectAnswer = value;
                                              });
                                            },
                                          ),
                                        ),
                                      ] else ...[
                                        _buildTextField(
                                          controller: _correctAnswerController,
                                          label: '正確答案',
                                          maxLines: 2,
                                        ),
                                      ],
                                      const SizedBox(height: 16),
                                      _buildTextField(
                                        controller: _explanationController,
                                        label: '解釋（必填）',
                                        maxLines: 4,
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: _cancelEditing,
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: const Text('取消'),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: _submitQuestion,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green.shade600,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: const Text('儲存'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                              // 題目列表（編輯中略過該題，避免與上方表單重複顯示）
                              ...currentQuestions
                                  .where(
                                    (q) =>
                                        _editingQuestion == null ||
                                        q.id != _editingQuestion!.id,
                                  )
                                  .map((question) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  question.question,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1F2937),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                if (question.type == QuestionType.multipleChoice &&
                                                    question.options != null) ...[
                                                  ...question.options!.asMap().entries.map((entry) {
                                                    final index = entry.key;
                                                    final option = entry.value;
                                                    final letter = String.fromCharCode(65 + index); // A, B, C, D
                                                    final isCorrect = question.correctAnswer == letter;
                                                    return Padding(
                                                      padding: const EdgeInsets.only(bottom: 4),
                                                      child: Row(
                                                        children: [
                                                          Text(
                                                            '$letter. ',
                                                            style: TextStyle(
                                                              fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                                              color: isCorrect ? Colors.green.shade600 : Colors.grey[700],
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              option,
                                                              style: TextStyle(
                                                                fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                                                color: isCorrect ? Colors.green.shade600 : Colors.grey[700],
                                                              ),
                                                            ),
                                                          ),
                                                          if (isCorrect)
                                                            Icon(
                                                              Icons.check_circle,
                                                              color: Colors.green.shade600,
                                                              size: 16,
                                                            ),
                                                        ],
                                                      ),
                                                    );
                                                  }),
                                                ] else ...[
                                                  Text(
                                                    '答案: ${question.correctAnswer}',
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ],
                                                if (question.explanation != null && question.explanation!.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    '解釋: ${question.explanation}',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          AdaptivePopupMenuButton.icon<String>(
                                            icon: PlatformInfo.isIOS26OrHigher()
                                                ? 'ellipsis.circle'
                                                : Icons.more_vert,
                                            buttonStyle: PopupButtonStyle.glass,
                                            size: 40,
                                            items: [
                                              AdaptivePopupMenuItem<String>(
                                                label: '編輯',
                                                value: 'edit',
                                                icon: PlatformInfo.isIOS26OrHigher()
                                                    ? 'pencil'
                                                    : Icons.edit,
                                              ),
                                              AdaptivePopupMenuItem<String>(
                                                label: '刪除',
                                                value: 'delete',
                                                icon: PlatformInfo.isIOS26OrHigher()
                                                    ? 'trash'
                                                    : Icons.delete,
                                              ),
                                            ],
                                            onSelected: (_, entry) {
                                              final value = entry.value;
                                              if (value == 'edit') {
                                                _startEditing(question);
                                              } else if (value == 'delete') {
                                                _deleteQuestion(question);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      // 教師評語
                                      if (question.teacherComment != null && question.teacherComment!.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.amber.shade200,
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons.comment,
                                                color: Colors.amber.shade700,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '教師評語',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.amber.shade900,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      question.teacherComment!,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.amber.shade900,
                                                      ),
                                                    ),
                                                    if (question.teacherCommentUpdatedAt != null) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${question.teacherCommentUpdatedAt!.toString().split(' ')[0]}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.amber.shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }),
        const SizedBox(height: 20),
      ],
    );
  }

  void _showAddQuestionDialog(BuildContext context) {
    // 重置表單
    _cancelEditing();

    // 在對話框內使用獨立的狀態變數
    QuestionType dialogSelectedType = _selectedType;
    String? dialogSelectedCorrectAnswer = _selectedCorrectAnswer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setDialogState) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
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
                      const Expanded(
                        child: Text(
                          '新增題目',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _cancelEditing();
                        },
                      ),
                    ],
                  ),
                ),
                // 表單內容
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 獲取鍵盤高度
                      final keyboardHeight =
                          MediaQuery.of(context).viewInsets.bottom;
                      return SingleChildScrollView(
                        controller: scrollController,
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 20,
                          bottom: 20 + keyboardHeight,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SegmentedButton<QuestionType>(
                                segments: const [
                                  ButtonSegment(
                                    value: QuestionType.multipleChoice,
                                    label: Text('選擇題'),
                                  ),
                                  ButtonSegment(
                                    value: QuestionType.shortAnswer,
                                    label: Text('問答題'),
                                  ),
                                ],
                                selected: {dialogSelectedType},
                                onSelectionChanged:
                                    (Set<QuestionType> newSelection) {
                                  setDialogState(() {
                                    dialogSelectedType = newSelection.first;
                                    if (dialogSelectedType ==
                                        QuestionType.shortAnswer) {
                                      dialogSelectedCorrectAnswer = null;
                                    } else {
                                      dialogSelectedCorrectAnswer = 'A';
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildTextField(
                              controller: _questionController,
                              label: '題目',
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            if (dialogSelectedType ==
                                QuestionType.multipleChoice) ...[
                              _buildTextField(
                                controller: _optionAController,
                                label: '選項 A',
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _optionBController,
                                label: '選項 B',
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _optionCController,
                                label: '選項 C',
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _optionDController,
                                label: '選項 D',
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey[300]!),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: dialogSelectedCorrectAnswer,
                                  decoration: const InputDecoration(
                                    labelText: '正確答案',
                                    border: InputBorder.none,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'A',
                                      child: Text('A'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'B',
                                      child: Text('B'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'C',
                                      child: Text('C'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'D',
                                      child: Text('D'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setDialogState(() {
                                      dialogSelectedCorrectAnswer = value;
                                    });
                                  },
                                ),
                              ),
                            ] else ...[
                              _buildTextField(
                                controller: _correctAnswerController,
                                label: '正確答案',
                                maxLines: 2,
                              ),
                            ],
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _explanationController,
                              label: '解釋（必填）',
                              maxLines: 4,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  _selectedType = dialogSelectedType;
                                  _selectedCorrectAnswer =
                                      dialogSelectedCorrectAnswer;
                                });
                                await _submitQuestion();
                                if (mounted && Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                '建立題目',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade600),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        maxLines: maxLines,
      ),
    );
  }
}
