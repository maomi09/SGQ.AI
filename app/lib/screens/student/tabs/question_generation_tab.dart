import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/grammar_topic_provider.dart';
import '../../../providers/question_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/question_model.dart';
import '../../../utils/user_animal_helper.dart';
import '../../chatgpt/chatgpt_chat_screen.dart';
import '../../badges/badges_screen.dart';

class QuestionGenerationTab extends StatefulWidget {
  const QuestionGenerationTab({super.key});

  @override
  State<QuestionGenerationTab> createState() => _QuestionGenerationTabState();
}

class _QuestionGenerationTabState extends State<QuestionGenerationTab> {
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

  Future<void> _loadQuestions() async {
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
    final questionProvider = Provider.of<QuestionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (grammarTopicProvider.selectedTopic != null && authProvider.currentUser != null) {
      await questionProvider.loadQuestions(
        authProvider.currentUser!.id,
        grammarTopicId: grammarTopicProvider.selectedTopic!.id,
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
        'explanation': _explanationController.text.isEmpty ? null : _explanationController.text,
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
      // 檢查該課程是否已有題目
      final currentQuestions = grammarTopicProvider.selectedTopic != null
          ? questionProvider.questions
              .where((q) => q.grammarTopicId == grammarTopicProvider.selectedTopic!.id)
              .toList()
          : <QuestionModel>[];
      
      if (currentQuestions.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('每個課程只能創建一個題目，請先刪除現有題目'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // 建立新題目
      final question = QuestionModel(
        id: '',
        studentId: authProvider.currentUser!.id,
        grammarTopicId: grammarTopicProvider.selectedTopic!.id,
        type: _selectedType,
        question: _questionController.text,
        options: options,
        correctAnswer: correctAnswer,
        explanation: _explanationController.text.isEmpty ? null : _explanationController.text,
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('確認刪除'),
        content: const Text('確定要刪除此題目嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
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
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    // 獲取當前主題的題目
    final currentQuestions = grammarTopicProvider.selectedTopic != null
        ? questionProvider.questions
            .where((q) => q.grammarTopicId == grammarTopicProvider.selectedTopic!.id)
            .toList()
        : <QuestionModel>[];

    return Scaffold(
      body: SafeArea(
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
            // 頂部區域
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  // 頭像和問候語
                  Expanded(
                    child: Row(
                      children: [
                        FutureBuilder<String>(
                          future: user != null ? UserAnimalHelper.getUserAnimal(user.id) : Future.value('👤'),
                          builder: (context, snapshot) {
                            final animal = snapshot.data ?? (user != null ? UserAnimalHelper.getDefaultAnimal(user.id) : '👤');
                            return CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.green.shade400,
                              child: Text(
                                animal,
                                style: const TextStyle(
                                  fontSize: 32,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '出題區',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              if (grammarTopicProvider.selectedTopic != null)
                                Text(
                                  grammarTopicProvider.selectedTopic!.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else
                                Text(
                                  '請選擇主題',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 右側圖標
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.stars),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BadgesScreen(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat),
                        onPressed: () {
                          showChatDialog(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 主題選擇器
            if (grammarTopicProvider.selectedTopic == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
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
                        child: DropdownButton<String>(
                          value: null,
                          hint: const Text('請選擇文法主題'),
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: grammarTopicProvider.topics.map((topic) {
                            return DropdownMenuItem(
                              value: topic.id,
                              child: Text(topic.title),
                            );
                          }).toList(),
                          onChanged: (topicId) {
                            if (topicId != null) {
                              Provider.of<GrammarTopicProvider>(context, listen: false)
                                  .selectTopic(topicId);
                              _loadQuestions();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFF1F2937)),
                      onPressed: () async {
                        final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
                        await grammarTopicProvider.loadTopics();
                      },
                      tooltip: '刷新',
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade400,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '文法主題: ${grammarTopicProvider.selectedTopic!.title}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  if (grammarTopicProvider.selectedTopic!.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      grammarTopicProvider.selectedTopic!.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1F2937)),
                              onSelected: (topicId) {
                                Provider.of<GrammarTopicProvider>(context, listen: false)
                                    .selectTopic(topicId);
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    _loadQuestions();
                                  }
                                });
                              },
                              itemBuilder: (context) => grammarTopicProvider.topics.map((topic) {
                                return PopupMenuItem(
                                  value: topic.id,
                                  child: Text(topic.title),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFF1F2937)),
                      onPressed: () async {
                        final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
                        await grammarTopicProvider.loadTopics();
                        _loadQuestions();
                      },
                      tooltip: '刷新',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            // 內容區域
            Expanded(
              child: grammarTopicProvider.selectedTopic == null
                  ? Center(
                      child: Text(
                        '請先選擇文法主題',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : currentQuestions.isEmpty && _editingQuestion == null
                      ? Center(
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
                                '點擊右下角 + 號新增題目',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.only(
                            left: 20,
                            right: 20,
                            bottom: MediaQuery.of(context).padding.bottom + 100,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                        label: '解釋（選填）',
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
                              // 題目列表
                              ...currentQuestions.map((question) {
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
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert),
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _startEditing(question);
                                              } else if (value == 'delete') {
                                                _deleteQuestion(question);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit, size: 20),
                                                    SizedBox(width: 8),
                                                    Text('編輯'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete, size: 20, color: Colors.red),
                                                    SizedBox(width: 8),
                                                    Text('刪除', style: TextStyle(color: Colors.red)),
                                                  ],
                                                ),
                                              ),
                                            ],
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
                          ),
                        ),
            ),
          ],
        ),
      ),
      ),
      floatingActionButton: grammarTopicProvider.selectedTopic != null && 
          _editingQuestion == null &&
          currentQuestions.isEmpty
          ? FloatingActionButton(
              onPressed: () => _showAddQuestionDialog(context),
              backgroundColor: Colors.green.shade600,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  void _showAddQuestionDialog(BuildContext context) {
    // 檢查該課程是否已有題目
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
    final questionProvider = Provider.of<QuestionProvider>(context, listen: false);
    
    final currentQuestions = grammarTopicProvider.selectedTopic != null
        ? questionProvider.questions
            .where((q) => q.grammarTopicId == grammarTopicProvider.selectedTopic!.id)
            .toList()
        : <QuestionModel>[];
    
    if (currentQuestions.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('每個課程只能創建一個題目，請先刪除現有題目'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
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
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
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
                            onSelectionChanged: (Set<QuestionType> newSelection) {
                              setDialogState(() {
                                dialogSelectedType = newSelection.first;
                                // 切換類型時重置正確答案
                                if (dialogSelectedType == QuestionType.shortAnswer) {
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
                        if (dialogSelectedType == QuestionType.multipleChoice) ...[
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
                              value: dialogSelectedCorrectAnswer,
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
                          label: '解釋（選填）',
                          maxLines: 4,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () async {
                            // 更新主狀態變數
                            setState(() {
                              _selectedType = dialogSelectedType;
                              _selectedCorrectAnswer = dialogSelectedCorrectAnswer;
                            });
                            await _submitQuestion();
                            if (mounted && Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
