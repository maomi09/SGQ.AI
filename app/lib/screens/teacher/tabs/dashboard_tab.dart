import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/grammar_topic_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../models/question_model.dart';
import '../../../models/badge_model.dart';
import '../../../models/class_model.dart';
import '../../../utils/user_animal_helper.dart';
import '../../../utils/error_handler.dart';
import '../../../providers/teacher_auto_refresh_provider.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _studentsProgress = [];
  bool _isLoading = true;
  Set<String> _resolvedStudentIds = {}; // 已標記為「已完成」的學生 ID
  Map<String, bool> _studentsOnlineStatus = {}; // 學生的登入狀態
  String? _selectedClassId; // 選中的班級 ID
  bool _isTopPanelCollapsed = false; // 頂部篩選與資訊字卡收合狀態

  late TeacherAutoRefreshProvider _autoRefreshProvider;
  int _lastRefreshToken = -1;
  bool _listenerAttached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 啟動共用倒數與刷新事件監聽（讓 Dashboard / Statistics 同步）
      _autoRefreshProvider = Provider.of<TeacherAutoRefreshProvider>(context, listen: false);
      _lastRefreshToken = _autoRefreshProvider.refreshToken;
      _autoRefreshProvider.addListener(_handleAutoRefreshTokenChanged);
      _listenerAttached = true;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        // 載入老師的班級列表
        Provider.of<ClassProvider>(context, listen: false)
            .loadTeacherClasses(authProvider.currentUser!.id);
      }
      Provider.of<GrammarTopicProvider>(context, listen: false).loadTopics();
    });
    _loadStudentsProgress();
  }

  @override
  void dispose() {
    if (_listenerAttached) {
      _autoRefreshProvider.removeListener(_handleAutoRefreshTokenChanged);
    }
    super.dispose();
  }

  void _handleAutoRefreshTokenChanged() {
    if (!mounted) return;
    final token = _autoRefreshProvider.refreshToken;
    if (token != _lastRefreshToken) {
      _lastRefreshToken = token;
      _loadStudentsProgress();
    }
  }

  Future<void> _loadStudentsProgress() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 同時載入已標記為「已完成」的學生 ID
      _resolvedStudentIds = await _supabaseService.getResolvedStudentIds();
      
      // 根據選中的班級篩選學生
      final progress = await _supabaseService.getAllStudentsProgress(classId: _selectedClassId);
      
      // 獲取所有學生的登入狀態
      final studentIds = progress.map((s) => s['student_id'] as String).toList();
      _studentsOnlineStatus = await _supabaseService.getStudentsOnlineStatus(studentIds);
      print('Dashboard: Received ${progress.length} students');
      
      // 獲取所有課程，建立 ID 到課程名稱的映射
      final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
      await grammarTopicProvider.loadTopics();
      final topics = grammarTopicProvider.topics;
      final topicMap = <String, String>{};
      for (var topic in topics) {
        topicMap[topic.id] = topic.title;
      }
      print('Dashboard: Loaded ${topics.length} grammar topics');
      
      // 批量查詢所有學生的題目（優化：一次查詢取代 N 次查詢）
      final allQuestionsByStudent = await _supabaseService.getAllQuestionsForStudents(studentIds);
      print('Dashboard: Batch loaded questions for ${allQuestionsByStudent.length} students');
      
      // 為每個學生添加詳細的階段信息
      final List<Map<String, dynamic>> enrichedProgress = [];
      for (var student in progress) {
        final studentId = student['student_id'] as String;
        
        // 從批量查詢結果中獲取該學生的題目
        final questions = allQuestionsByStudent[studentId] ?? [];
        
        // 計算每個階段的題目數和完成狀態
        final stageCounts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0};
        final completedStagesCount = <int, int>{1: 0, 2: 0, 3: 0, 4: 0};
        int totalCompletedStages = 0;
        int maxCompletedStage = 0;
        
        for (var question in questions) {
          final stage = question.stage;
          stageCounts[stage] = (stageCounts[stage] ?? 0) + 1;
          
          if (question.completedStages != null && question.completedStages!.isNotEmpty) {
            for (var completedStage in question.completedStages!.keys) {
              completedStagesCount[completedStage] = (completedStagesCount[completedStage] ?? 0) + 1;
              totalCompletedStages++;
              if (completedStage > maxCompletedStage) {
                maxCompletedStage = completedStage;
              }
            }
          }
        }
        
        int currentStage = 1;
        
        if (questions.isNotEmpty) {
          // 按 created_at 優先排序，獲取最新創建的題目
          final sortedQuestions = List<QuestionModel>.from(questions);
          sortedQuestions.sort((a, b) {
            final aCreated = a.createdAt;
            final bCreated = b.createdAt;
            final createdCompare = bCreated.compareTo(aCreated);
            if (createdCompare != 0) {
              return createdCompare;
            }
            final aUpdated = a.updatedAt ?? a.createdAt;
            final bUpdated = b.updatedAt ?? b.createdAt;
            return bUpdated.compareTo(aUpdated);
          });
          
          final latestQuestion = sortedQuestions.first;
          currentStage = latestQuestion.stage;
          final currentGrammarTopicId = latestQuestion.grammarTopicId;
          final currentGrammarTopicName = topicMap[currentGrammarTopicId] ?? '未知課程';
          final isStage4Completed = latestQuestion.completedStages?.containsKey(4) ?? false;
          
          final stageDuration = latestQuestion.updatedAt != null
              ? DateTime.now().difference(latestQuestion.updatedAt!)
              : DateTime.now().difference(latestQuestion.createdAt);
          
          double avgStage = 0;
          int totalQuestions = questions.length;
          if (totalQuestions > 0) {
            for (var question in questions) {
              avgStage += question.stage;
            }
            avgStage = avgStage / totalQuestions;
          } else {
            avgStage = 1.0;
          }
          
          enrichedProgress.add({
            ...student,
            'current_stage': currentStage,
            'current_grammar_topic_id': currentGrammarTopicId,
            'current_grammar_topic_name': currentGrammarTopicName,
            'is_stage_4_completed': isStage4Completed,
            'stage_duration': stageDuration,
            'stage_updated_at': latestQuestion.updatedAt?.toIso8601String() ?? latestQuestion.createdAt.toIso8601String(),
            'stage_distribution': stageCounts,
            'completed_stages_count': completedStagesCount,
            'total_questions': totalQuestions,
            'average_stage': avgStage,
            'total_completed_stages': totalCompletedStages,
            'max_completed_stage': maxCompletedStage,
          });
        } else {
          enrichedProgress.add({
            ...student,
            'current_stage': 1,
            'current_grammar_topic_id': null,
            'current_grammar_topic_name': null,
            'is_stage_4_completed': false,
            'stage_duration': null,
            'stage_updated_at': null,
            'stage_distribution': stageCounts,
            'completed_stages_count': completedStagesCount,
            'total_questions': 0,
            'average_stage': 1.0,
            'total_completed_stages': 0,
            'max_completed_stage': 0,
          });
        }
      }
      
      setState(() {
        _studentsProgress = enrichedProgress;
        _isLoading = false;
      });
    } catch (e) {
      print('Dashboard: Error loading students progress: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getStageColor(int stage) {
    switch (stage) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  bool _isStuck(Map<String, dynamic> student) {
    if (student['last_activity'] == null) return false;
    final lastActivity = DateTime.parse(student['last_activity']);
    final now = DateTime.now();
    final duration = now.difference(lastActivity);
    return duration.inHours > 24;
  }

  bool _isStageAbnormal(Map<String, dynamic> student) {
    // 檢查是否有學生的階段明顯落後
    // 條件：有題目但平均階段低於1.5，且最後活動時間超過24小時
    final totalQuestions = student['total_questions'] as int? ?? 0;
    final avgStage = student['average_stage'] as double? ?? 1.0;
    final maxCompletedStage = student['max_completed_stage'] as int? ?? 0;
    
    // 如果有題目但進度很慢（平均階段低於1.5且沒有完成任何階段），且停留超過24小時
    if (totalQuestions > 0 && avgStage < 1.5 && maxCompletedStage == 0) {
      if (student['last_activity'] != null) {
        final lastActivity = DateTime.parse(student['last_activity']);
        final now = DateTime.now();
        final duration = now.difference(lastActivity);
        return duration.inHours > 24;
      }
    }
    return false;
  }

  bool _hasAlert(Map<String, dynamic> student) {
    // 如果學生已被標記為「已完成」，則不顯示警告
    final studentId = student['student_id'] as String?;
    if (studentId != null && _resolvedStudentIds.contains(studentId)) {
      return false;
    }
    return _isStuck(student) || _isStageAbnormal(student);
  }

  String _getStageName(int stage) {
    switch (stage) {
      case 1:
        return '認知鷹架';
      case 2:
        return '形式鷹架';
      case 3:
        return '語言鷹架';
      case 4:
        return '後設認知鷹架';
      default:
        return '未知';
    }
  }

  // 格式化停留時間
  void _showStudentDetailDialog(
    BuildContext context,
    Map<String, dynamic> student,
    Color stageColor,
    Map<int, int> stageDistribution,
    Map<int, int> completedStagesCount,
    double avgStage,
    bool hasAlert,
    bool isStuck,
    bool isAbnormal,
  ) {
    final stage = student['current_stage'] as int? ?? 1;
    final studentId = student['student_id'] as String?;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '學生詳細資訊',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 學生基本資訊
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    student['student_name']?.toString().isNotEmpty == true
                                        ? student['student_name'] as String
                                        : student['student_email'] as String? ?? '學生',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                                // 登入狀態指示器
                                Builder(
                                  builder: (context) {
                                    final studentId = student['student_id'] as String;
                                    final isOnline = _studentsOnlineStatus[studentId] ?? false;
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isOnline ? Colors.green : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isOnline ? '登入中' : '已登出',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isOnline ? Colors.green.shade700 : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                            if (student['student_id_number']?.toString().isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text(
                                '學號: ${student['student_id_number']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                            if (student['student_email'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '電子郵件: ${student['student_email']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 當前課程和階段
                      _buildDetailRow(
                        icon: Icons.book_outlined,
                        label: '當前課程',
                        value: student['current_grammar_topic_name']?.toString() ?? '尚未選擇課程',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.label,
                        label: '目前階段',
                        value: '階段 $stage - ${_getStageName(stage)}',
                        color: stageColor,
                      ),
                      if (student['is_stage_4_completed'] == true) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              '已完成階段四',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // 階段停留時間
                      if (student['stage_duration'] != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.access_time,
                          label: '階段停留時間',
                          value: _formatDuration(student['stage_duration'] as Duration),
                          color: Colors.orange,
                        ),
                      ],
                      // 最後活動時間
                      if (student['last_activity'] != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.schedule,
                          label: '最後活動',
                          value: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(student['last_activity'])),
                          color: Colors.grey,
                        ),
                      ],
                      // 平均階段
                      if (avgStage != stage.toDouble()) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.trending_up,
                          label: '平均階段',
                          value: avgStage.toStringAsFixed(1),
                          color: Colors.purple,
                        ),
                      ],
                      // 階段分布
                      if (stageDistribution.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          '階段分布',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [1, 2, 3, 4].where((s) {
                            final count = stageDistribution[s] ?? 0;
                            return count > 0;
                          }).map((s) {
                            final count = stageDistribution[s] ?? 0;
                            final completed = completedStagesCount[s] ?? 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _getStageColor(s).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _getStageColor(s), width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '階段 $s',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _getStageColor(s),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$count 題',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  if (completed > 0) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '完成: $completed',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      // 警告資訊（僅在未標記為「已完成」時顯示）
                      if (hasAlert) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.red.shade700),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      '需要關注',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (isStuck)
                                Text(
                                  '⚠️ 該學生在當前階段停留超過24小時',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red[700],
                                  ),
                                ),
                              if (isAbnormal)
                                Text(
                                  '⚠️ 該學生進度異常，請檢查',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    if (studentId == null) return;
                                    
                                    try {
                                      await _supabaseService.markStudentAttentionResolved(studentId);
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('已標記為「已完成」'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        // 重新載入數據
                                        _loadStudentsProgress();
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(ErrorHandler.getSafeErrorMessage(e)),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.check_circle, color: Colors.white),
                                  label: const Text(
                                    '新增完成',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '關閉',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '已停留 ${duration.inDays} 天 ${duration.inHours % 24} 小時';
    } else if (duration.inHours > 0) {
      return '已停留 ${duration.inHours} 小時 ${duration.inMinutes % 60} 分鐘';
    } else if (duration.inMinutes > 0) {
      return '已停留 ${duration.inMinutes} 分鐘';
    } else {
      return '剛進入此階段';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context);
    final user = authProvider.currentUser;

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
                          future: user != null ? UserAnimalHelper.getUserAnimal(user.id) : Future.value(''),
                          builder: (context, snapshot) {
                            final animal = snapshot.data ?? (user != null ? UserAnimalHelper.getDefaultAnimal(user.id) : '');
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '學生進度儀錶板',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                '追蹤學生學習進度',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
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
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          _autoRefreshProvider.forceRefreshNow();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.emoji_events),
                        onPressed: () {
                          _showAwardBadgeDialog(context);
                        },
                      ),
                      IconButton(
                        tooltip: _isTopPanelCollapsed ? '展開篩選與資訊' : '收起篩選與資訊',
                        icon: Icon(
                          _isTopPanelCollapsed ? Icons.unfold_more : Icons.unfold_less,
                        ),
                        onPressed: () {
                          setState(() {
                            _isTopPanelCollapsed = !_isTopPanelCollapsed;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Selector<TeacherAutoRefreshProvider, int>(
                selector: (_, provider) => provider.remainingSeconds,
                builder: (context, value, _) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '下次自動刷新：$value 秒',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _isTopPanelCollapsed
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Column(
                children: [
                  // 班級選擇器
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      child: Row(
                        children: [
                          Icon(Icons.class_, color: Colors.indigo.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedClassId,
                                hint: const Text('所有班級'),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('所有班級'),
                                  ),
                                  ...classProvider.classes.map((classModel) => DropdownMenuItem<String>(
                                    value: classModel.id,
                                    child: Text(classModel.name),
                                  )),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedClassId = value;
                                  });
                                  _loadStudentsProgress();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 統計卡片
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
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
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people,
                              size: 24,
                              color: Colors.grey[800],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_studentsProgress.length}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '總學生數',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[400],
                    ),
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 24,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_studentsProgress.where((s) => _hasAlert(s)).length}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '需要關注',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[400],
                    ),
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 24,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_studentsOnlineStatus.values.where((isOnline) => isOnline).length}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '登入中',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[400],
                    ),
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 24,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_studentsProgress.where((s) => s['is_stage_4_completed'] == true).length}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '已完成',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
            SizedBox(height: _isTopPanelCollapsed ? 8 : 24),
            // 學生列表
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: _CuteLoadingIndicator(
                        label: '整理資料中...',
                      ),
                    )
                  : _studentsProgress.isEmpty
                      ? Center(
                          child: Text(
                            '尚無學生資料',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(
                            left: 20,
                            right: 20,
                            bottom: MediaQuery.of(context).padding.bottom + 100,
                          ),
                          itemCount: _studentsProgress.length,
                          itemBuilder: (context, index) {
                            final student = _studentsProgress[index];
                            final hasAlert = _hasAlert(student);
                            final isStuck = _isStuck(student);
                            final isAbnormal = _isStageAbnormal(student);
                            final stage = student['current_stage'] as int? ?? 1;
                            final avgStage = student['average_stage'] as double? ?? 1.0;
                            final stageColor = _getStageColor(stage.round());
                            final stageDistribution = student['stage_distribution'] as Map<int, int>? ?? {};
                            final completedStagesCount = student['completed_stages_count'] as Map<int, int>? ?? {};

                            return InkWell(
                              onTap: () {
                                _showStudentDetailDialog(context, student, stageColor, stageDistribution, completedStagesCount, avgStage, hasAlert, isStuck, isAbnormal);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: hasAlert ? Colors.red[50] : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: hasAlert
                                      ? Border.all(color: Colors.red.shade300, width: 2)
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                children: [
                                  // 登入狀態指示器（左側圓點）
                                  Builder(
                                    builder: (context) {
                                      final studentId = student['student_id'] as String;
                                      final isOnline = _studentsOnlineStatus[studentId] ?? false;
                                      return Container(
                                        width: 12,
                                        height: 12,
                                        margin: const EdgeInsets.only(right: 16),
                                        decoration: BoxDecoration(
                                          color: isOnline ? Colors.green : Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      );
                                    },
                                  ),
                                  Stack(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: stageColor,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$stage',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // 如果完成階段四，顯示打勾圖示
                                      if (student['is_stage_4_completed'] == true)
                                        Positioned(
                                          right: -2,
                                          top: -2,
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student['student_name']?.toString().isNotEmpty == true
                                              ? student['student_name'] as String
                                              : student['student_email'] as String? ?? '學生',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        if (student['student_id_number']?.toString().isNotEmpty == true) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '學號: ${student['student_id_number']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                        // 顯示當前課程
                                        if (student['current_grammar_topic_name'] != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.book_outlined,
                                                size: 14,
                                                color: Colors.blue[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  '課程: ${student['current_grammar_topic_name']}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.blue[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              '目前階段: ',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: stageColor.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: stageColor, width: 1),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        '階段 $stage - ${_getStageName(stage)}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: stageColor,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    // 如果完成階段四，顯示打勾圖示
                                                    if (student['is_stage_4_completed'] == true) ...[
                                                      const SizedBox(width: 6),
                                                      const Icon(
                                                        Icons.check_circle,
                                                        color: Colors.green,
                                                        size: 16,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // 如果有警告，顯示警告圖示
                                        if (hasAlert) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.warning,
                                                size: 16,
                                                color: Colors.red[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  isStuck ? '停留超過24小時' : '進度異常',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.red[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // 右側箭頭圖示
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
                            ),
                            );
                          },
                        ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _showAwardBadgeDialog(BuildContext context) {
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String? selectedStudentId;
        String? selectedGrammarTopicId;
        String selectedMedalType = 'bronze';
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('授予徽章'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 選擇課程
                    const Text(
                      '選擇課程',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedGrammarTopicId,
                      hint: const Text('請選擇課程'),
                      items: grammarTopicProvider.topics.map((topic) {
                        return DropdownMenuItem<String>(
                          value: topic.id,
                          child: Text(topic.title),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedGrammarTopicId = value;
                          selectedStudentId = null; // 重置學生選擇
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // 選擇學生
                    if (selectedGrammarTopicId != null) ...[
                      const Text(
                        '選擇學生',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: selectedStudentId,
                        hint: const Text('請選擇學生'),
                        items: _studentsProgress.map((student) {
                          return DropdownMenuItem<String>(
                            value: student['student_id'] as String,
                            child: Text(
                              '${student['student_name'] ?? student['student_email'] ?? '學生'} (${student['student_id_number'] ?? ''})',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedStudentId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    // 選擇獎牌類型
                    if (selectedStudentId != null) ...[
                      const Text(
                        '選擇獎牌',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMedalOption(
                              'bronze',
                              '銅牌',
                              Colors.brown.shade400,
                              selectedMedalType == 'bronze',
                              () => setState(() => selectedMedalType = 'bronze'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMedalOption(
                              'silver',
                              '銀牌',
                              Colors.grey.shade400,
                              selectedMedalType == 'silver',
                              () => setState(() => selectedMedalType = 'silver'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMedalOption(
                              'gold',
                              '金牌',
                              Colors.amber.shade600,
                              selectedMedalType == 'gold',
                              () => setState(() => selectedMedalType = 'gold'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                if (selectedStudentId != null && selectedGrammarTopicId != null)
                  ElevatedButton(
                    onPressed: () async {
                      // 檢查是否已有徽章
                      final hasBadge = await _supabaseService.hasBadgeForTopic(
                        selectedStudentId!,
                        selectedGrammarTopicId!,
                      );
                      
                      if (hasBadge) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('該學生在此課程已有徽章，無法重複授予'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                        return;
                      }
                      
                      try {
                        await _awardBadge(
                          selectedStudentId!,
                          selectedGrammarTopicId!,
                          selectedMedalType,
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('徽章授予成功'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        print('Error awarding badge: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ErrorHandler.getSafeErrorMessage(e)),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('授予'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMedalOption(String type, String name, Color color, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.emoji_events,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _awardBadge(String studentId, String grammarTopicId, String medalType) async {
    final medalNames = {
      'bronze': '銅牌',
      'silver': '銀牌',
      'gold': '金牌',
    };
    
    final medalDescriptions = {
      'bronze': '銅牌代表良好的學習表現，是對您努力的肯定。',
      'silver': '銀牌代表優秀的學習成果，展現了您的持續進步。',
      'gold': '金牌代表卓越的學習成就，是對您傑出表現的最高肯定。',
    };

    final badge = BadgeModel(
      id: '',
      studentId: studentId,
      badgeType: medalType,
      badgeName: medalNames[medalType] ?? medalType,
      description: medalDescriptions[medalType] ?? '',
      earnedAt: DateTime.now(),
      grammarTopicId: grammarTopicId,
    );

    await _supabaseService.createBadge(badge);
    
    // 通知會通過 Realtime 自動發送到學生端，無需在此處發送
  }
}

class _CuteLoadingIndicator extends StatefulWidget {
  final String label;

  const _CuteLoadingIndicator({required this.label});

  @override
  State<_CuteLoadingIndicator> createState() => _CuteLoadingIndicatorState();
}

class _CuteLoadingIndicatorState extends State<_CuteLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * math.pi;
        final o1 = 0.4 + 0.6 * ((math.sin(t) + 1) / 2);
        final o2 = 0.4 + 0.6 * ((math.sin(t + 0.8) + 1) / 2);
        final o3 = 0.4 + 0.6 * ((math.sin(t + 1.6) + 1) / 2);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(opacity: o1, child: const Icon(Icons.pets, size: 24, color: Colors.orange)),
                const SizedBox(width: 8),
                Opacity(opacity: o2, child: const Icon(Icons.pets, size: 24, color: Colors.orange)),
                const SizedBox(width: 8),
                Opacity(opacity: o3, child: const Icon(Icons.pets, size: 24, color: Colors.orange)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.label,
              style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
          ],
        );
      },
    );
  }
}


