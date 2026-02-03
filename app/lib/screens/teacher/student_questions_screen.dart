import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/grammar_topic_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/question_model.dart';
import '../../models/grammar_topic_model.dart';
import '../../utils/error_handler.dart';

class StudentQuestionsScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String? studentIdNumber;

  const StudentQuestionsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.studentIdNumber,
  });

  @override
  State<StudentQuestionsScreen> createState() => _StudentQuestionsScreenState();
}

class _StudentQuestionsScreenState extends State<StudentQuestionsScreen> with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  List<QuestionModel> _allQuestions = [];
  Map<String, List<QuestionModel>> _questionsByTopic = {};
  Map<String, GrammarTopicModel> _topicMap = {};
  bool _isLoading = true;
  late TabController _tabController;
  QuestionModel? _selectedQuestionForChat;
  List<Map<String, dynamic>> _chatMessages = [];
  bool _isLoadingChat = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadQuestions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 載入所有課程
      final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
      await grammarTopicProvider.loadTopics();
      
      // 建立課程 ID 到課程模型的映射
      _topicMap = {};
      for (var topic in grammarTopicProvider.topics) {
        _topicMap[topic.id] = topic;
      }

      // 載入該學生的所有題目
      _allQuestions = await _supabaseService.getQuestions(widget.studentId);

      // 按課程分組
      _questionsByTopic = {};
      for (var question in _allQuestions) {
        if (!_questionsByTopic.containsKey(question.grammarTopicId)) {
          _questionsByTopic[question.grammarTopicId] = [];
        }
        _questionsByTopic[question.grammarTopicId]!.add(question);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading questions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChatMessages(QuestionModel question) async {
    setState(() {
      _isLoadingChat = true;
      _selectedQuestionForChat = question;
    });

    try {
      final messages = await _supabaseService.loadChatMessages(
        questionId: question.id,
        grammarTopicId: question.grammarTopicId,
      );
      
      setState(() {
        _chatMessages = messages;
        _isLoadingChat = false;
      });
    } catch (e) {
      print('Error loading chat messages: $e');
      setState(() {
        _isLoadingChat = false;
      });
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

  String _getStageName(int stage) {
    switch (stage) {
      case 1:
        return '階段一：認知鷹架';
      case 2:
        return '階段二：型式鷹架';
      case 3:
        return '階段三：語意鷹架';
      case 4:
        return '階段四：語用鷹架';
      default:
        return '階段 $stage';
    }
  }

  Future<void> _addComment(QuestionModel question) async {
    final TextEditingController commentController = TextEditingController(
      text: question.teacherComment ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加評語'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '題目: ${question.question}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: '請輸入評語...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(commentController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        await _supabaseService.updateQuestion(question.id, {
          'teacher_comment': result.isEmpty ? null : result,
          'teacher_comment_updated_at': DateTime.now().toIso8601String(),
        });
        
        // 通知會通過 Realtime 自動發送到學生端，無需在此處發送
        
        // 重新載入題目
        await _loadQuestions();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('評語已保存'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
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
  }

  @override
  Widget build(BuildContext context) {
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
              // 頂部標題欄
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.studentName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          if (widget.studentIdNumber != null && widget.studentIdNumber!.isNotEmpty)
                            Text(
                              '學號: ${widget.studentIdNumber}',
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
              // 頁籤欄
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.green.shade600,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.green.shade600,
                  tabs: const [
                    Tab(text: '學生題目'),
                    Tab(text: 'AI小幫手對話紀錄'),
                  ],
                ),
              ),
              // 內容區域
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 第一個頁籤：學生題目
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _questionsByTopic.isEmpty
                            ? Center(
                                child: Text(
                                  '該學生尚未創建任何題目',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '學生題目',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                ..._questionsByTopic.entries.map((entry) {
                                  final topicId = entry.key;
                                  final questions = entry.value;
                                  final topic = _topicMap[topicId];
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 24),
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.book_outlined,
                                              color: Colors.green.shade600,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                topic?.title ?? '未知課程',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1F2937),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        ...questions.map((question) {
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 16),
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.grey.shade200,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        question.question,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w500,
                                                          color: Color(0xFF1F2937),
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(
                                                        question.teacherComment != null
                                                            ? Icons.edit
                                                            : Icons.add_comment,
                                                        color: Colors.green.shade600,
                                                      ),
                                                      onPressed: () => _addComment(question),
                                                      tooltip: question.teacherComment != null
                                                          ? '編輯評語'
                                                          : '添加評語',
                                                    ),
                                                  ],
                                                ),
                                                if (question.type == QuestionType.multipleChoice &&
                                                    question.options != null) ...[
                                                  const SizedBox(height: 8),
                                                  ...question.options!.asMap().entries.map((entry) {
                                                    final index = entry.key;
                                                    final option = entry.value;
                                                    return Padding(
                                                      padding: const EdgeInsets.only(bottom: 4),
                                                      child: Text(
                                                        '${String.fromCharCode(65 + index)}. $option',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.grey[700],
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ],
                                                if (question.correctAnswer != null) ...[
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    '正確答案: ${question.correctAnswer}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.green.shade700,
                                                    ),
                                                  ),
                                                ],
                                                if (question.teacherComment != null) ...[
                                                  const SizedBox(height: 12),
                                                  Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber.shade50,
                                                      borderRadius: BorderRadius.circular(8),
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
                                        }).toList(),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                  ],
                                ),
                              ),
                    // 第二個頁籤：AI小幫手對話紀錄
                    _buildChatHistoryTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatHistoryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allQuestions.isEmpty) {
      return Center(
        child: Text(
          '該學生尚未創建任何題目',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return Column(
      children: [
        // 題目選擇器
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '請選擇要查看對話紀錄的題目',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount: _allQuestions.length,
                  itemBuilder: (context, index) {
                    final question = _allQuestions[index];
                    final topic = _topicMap[question.grammarTopicId];
                    final isSelected = _selectedQuestionForChat?.id == question.id;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isSelected ? Colors.green.shade50 : Colors.white,
                      child: ListTile(
                        title: Text(
                          question.question.length > 50
                              ? '${question.question.substring(0, 50)}...'
                              : question.question,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '課程: ${topic?.title ?? '未知課程'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '階段 ${question.stage}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: Colors.green.shade600)
                            : const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _loadChatMessages(question),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // 對話紀錄顯示區域
        Expanded(
          child: _selectedQuestionForChat == null
              ? Center(
                  child: Text(
                    '請選擇一個題目以查看對話紀錄',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                )
              : _isLoadingChat
                  ? const Center(child: CircularProgressIndicator())
                  : _chatMessages.isEmpty
                      ? Center(
                          child: Text(
                            '該題目尚未有對話紀錄',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : _buildChatMessagesList(),
        ),
      ],
    );
  }

  Widget _buildChatMessagesList() {
    // 按階段分組對話紀錄
    Map<int, List<Map<String, dynamic>>> messagesByStage = {};
    for (var message in _chatMessages) {
      final stage = message['stage'] as int;
      if (!messagesByStage.containsKey(stage)) {
        messagesByStage[stage] = [];
      }
      messagesByStage[stage]!.add(message);
    }

    final sortedStages = messagesByStage.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顯示選中的題目資訊
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.help_outline, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '題目',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedQuestionForChat!.question,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green.shade900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 按階段顯示對話紀錄
          ...sortedStages.map((stage) {
            final messages = messagesByStage[stage]!;
            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 階段標題
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.label, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _getStageName(stage),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 對話紀錄
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: messages.map((message) {
                        final isUser = message['type'] == 'user';
                        final content = message['content'] as String;
                        final createdAt = message['created_at'] as String?;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: isUser
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            children: [
                              if (!isUser) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.green.shade600,
                                  child: const Icon(
                                    Icons.smart_toy,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? Colors.blue.shade50
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isUser
                                          ? Colors.blue.shade200
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        content,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[900],
                                        ),
                                      ),
                                      if (createdAt != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDateTime(createdAt),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              if (isUser) ...[
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.blue.shade600,
                                  child: const Icon(
                                    Icons.person,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }
}

