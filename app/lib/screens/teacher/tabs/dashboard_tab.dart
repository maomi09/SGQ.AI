import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/grammar_topic_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../models/question_model.dart';
import '../../../models/badge_model.dart';
import '../../../utils/user_animal_helper.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _studentsProgress = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GrammarTopicProvider>(context, listen: false).loadTopics();
    });
    _loadStudentsProgress();
    
    // 設置自動刷新：每30秒刷新一次
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadStudentsProgress();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStudentsProgress() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final progress = await _supabaseService.getAllStudentsProgress();
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
      
      // 為每個學生添加詳細的階段信息
      final List<Map<String, dynamic>> enrichedProgress = [];
      for (var student in progress) {
        final studentId = student['student_id'] as String;
        print('Dashboard: Processing student ${student['student_name']} with student_id=$studentId');
        print('Dashboard: Student data keys: ${student.keys.toList()}');
        
        // 獲取學生的所有題目（不按課程過濾）
        try {
          print('Dashboard: Calling getQuestions for student_id=$studentId');
          final questions = await _supabaseService.getQuestions(studentId);
          print('Student ${student['student_name']}: Found ${questions.length} questions');
          
          // 如果沒有找到題目，記錄警告
          if (questions.isEmpty) {
            print('WARNING: No questions found for student $studentId (${student['student_name']})');
            print('This could be due to:');
            print('1. Student has not created any questions yet');
            print('2. RLS policy preventing teacher from reading student questions');
            print('3. student_id mismatch between users and questions tables');
          }
          
          // 計算每個階段的題目數和完成狀態
          final stageCounts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0};
          final completedStagesCount = <int, int>{1: 0, 2: 0, 3: 0, 4: 0};
          int totalCompletedStages = 0;
          int maxCompletedStage = 0; // 追蹤學生完成過的最高階段
          
          for (var question in questions) {
            final stage = question.stage;
            stageCounts[stage] = (stageCounts[stage] ?? 0) + 1;
            
            // 檢查 completed_stages 來確定學生完成的階段
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
          
          // 計算當前階段：直接使用題目的 stage 欄位（學生在ChatGPT對話中選擇的階段）
          // 如果有多個題目，使用最新的題目所在的階段（按 updated_at 排序）
          int currentStage = 1;
          
          if (questions.isNotEmpty) {
            // 打印所有題目的原始數據（用於調試）
            print('Student ${student['student_name']}: All questions before sorting:');
            for (var q in questions) {
              print('  - Question ${q.id.substring(0, 8)}: stage=${q.stage}, updated_at=${q.updatedAt}, created_at=${q.createdAt}');
            }
            
            // 按 created_at 優先排序，獲取最新創建的題目（代表當前活躍的課程）
            // 如果 created_at 相同，再按 updated_at 排序
            // 這樣可以確保新課程的題目優先於舊課程的題目，即使舊課程的題目最近有更新
            final sortedQuestions = List<QuestionModel>.from(questions);
            sortedQuestions.sort((a, b) {
              // 首先按 created_at 降序排序（最新創建的在前）
              final aCreated = a.createdAt;
              final bCreated = b.createdAt;
              final createdCompare = bCreated.compareTo(aCreated);
              if (createdCompare != 0) {
                return createdCompare;
              }
              // 如果 created_at 相同，再按 updated_at 降序排序
              final aUpdated = a.updatedAt ?? a.createdAt;
              final bUpdated = b.updatedAt ?? b.createdAt;
              return bUpdated.compareTo(aUpdated);
            });
            
            // 使用最新創建題目的 stage 和 grammar_topic_id（代表當前活躍的課程）
            final latestQuestion = sortedQuestions.first;
            currentStage = latestQuestion.stage;
            final currentGrammarTopicId = latestQuestion.grammarTopicId;
            final currentGrammarTopicName = topicMap[currentGrammarTopicId] ?? '未知課程';
            
            // 檢查最新題目是否完成了階段四
            final isStage4Completed = latestQuestion.completedStages?.containsKey(4) ?? false;
            
            // 計算在當前階段的停留時間
            // 使用 updated_at 作為進入當前階段的時間（當 stage 改變時，updated_at 會更新）
            final stageDuration = latestQuestion.updatedAt != null
                ? DateTime.now().difference(latestQuestion.updatedAt!)
                : DateTime.now().difference(latestQuestion.createdAt);
            
            print('Student ${student['student_name']}: Current stage = $currentStage, current course = $currentGrammarTopicName, stage 4 completed = $isStage4Completed, stage duration = ${stageDuration.inMinutes} minutes (latest question: ${latestQuestion.id.substring(0, 8)}, stage=${latestQuestion.stage}, grammar_topic_id=$currentGrammarTopicId, updated_at=${latestQuestion.updatedAt}, created_at=${latestQuestion.createdAt})');
            
            // 打印排序後的前3個題目（用於調試）
            print('Student ${student['student_name']}: Top 3 questions after sorting (by created_at, then updated_at):');
            for (var q in sortedQuestions.take(3)) {
              print('  - Question ${q.id.substring(0, 8)}: course=${topicMap[q.grammarTopicId] ?? q.grammarTopicId}, stage=${q.stage}, grammar_topic_id=${q.grammarTopicId}, completed_stages=${q.completedStages}, updated_at=${q.updatedAt}, created_at=${q.createdAt}');
            }
            print('Student ${student['student_name']}: Selected latest question: course=${currentGrammarTopicName}, stage=$currentStage');
            
            // 計算平均階段（加權平均）
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
              'current_stage': currentStage, // 更新為正確的當前階段
              'current_grammar_topic_id': currentGrammarTopicId, // 當前課程 ID
              'current_grammar_topic_name': currentGrammarTopicName, // 當前課程名稱
              'is_stage_4_completed': isStage4Completed, // 是否完成階段四
              'stage_duration': stageDuration, // 在當前階段的停留時間
              'stage_updated_at': latestQuestion.updatedAt?.toIso8601String() ?? latestQuestion.createdAt.toIso8601String(), // 進入當前階段的時間
              'stage_distribution': stageCounts,
              'completed_stages_count': completedStagesCount,
              'total_questions': totalQuestions,
              'average_stage': avgStage,
              'total_completed_stages': totalCompletedStages,
              'max_completed_stage': maxCompletedStage,
            });
          } else {
            print('Student ${student['student_name']}: No questions, default stage = 1');
            
            // 計算平均階段（加權平均）
            double avgStage = 1.0;
            int totalQuestions = 0;
            
            // 即使沒有題目，也要添加基本信息
            enrichedProgress.add({
              ...student,
              'current_stage': 1,
              'current_grammar_topic_id': null,
              'current_grammar_topic_name': null,
              'is_stage_4_completed': false, // 沒有題目，未完成階段四
              'stage_duration': null, // 沒有題目，無法計算停留時間
              'stage_updated_at': null,
              'stage_distribution': stageCounts,
              'completed_stages_count': completedStagesCount,
              'total_questions': totalQuestions,
              'average_stage': avgStage,
              'total_completed_stages': 0,
              'max_completed_stage': 0,
            });
          }
        } catch (e) {
          print('Error enriching student ${studentId}: $e');
          enrichedProgress.add(student);
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
                            Text(
                              student['student_name']?.toString().isNotEmpty == true
                                  ? student['student_name'] as String
                                  : student['student_email'] as String? ?? '學生',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
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
                      // 警告資訊
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
                                  const Text(
                                    '需要關注',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
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
                        onPressed: _loadStudentsProgress,
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () {
                          // TODO: 通知功能
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
            const SizedBox(height: 24),
            // 學生列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
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
                          padding: const EdgeInsets.symmetric(horizontal: 20),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAwardBadgeDialog(context),
        backgroundColor: Colors.amber.shade600,
        icon: const Icon(Icons.emoji_events, color: Colors.white),
        label: const Text(
          '授予徽章',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                              content: Text('授予徽章失敗: $e'),
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
  }
}
