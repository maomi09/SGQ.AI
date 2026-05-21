import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/grammar_topic_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../models/question_model.dart';
import '../../../utils/error_handler.dart';
import '../../../widgets/teacher_tab_top_bar.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _studentsProgress = [];
  bool _isLoading = true;
  Set<String> _resolvedStudentTopicKeys = {}; // 已標記為「已完成」的學生-課程鍵值
  Map<String, bool> _studentsOnlineStatus = {}; // 學生的登入狀態
  Map<String, bool> _studentsAiUsageStatus = {}; // 學生是否使用過 AI 小幫手
  bool _isTopPanelCollapsed = false; // 頂部篩選與資訊字卡收合狀態
  Map<String, int> _topicCompletionTargets = {};

  ClassProvider? _classProvider;
  String? _lastLoadedClassId;
  bool _classListenerAttached = false;
  static const Object _allClassesKey = Object();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _classProvider = Provider.of<ClassProvider>(context, listen: false);
      _lastLoadedClassId = _classProvider!.selectedClass?.id;
      _classProvider!.addListener(_onSelectedClassChanged);
      _classListenerAttached = true;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        await Provider.of<ClassProvider>(context, listen: false)
            .loadTeacherClasses(authProvider.currentUser!.id);
      }
      if (mounted) {
        await _loadStudentsProgress();
      }
    });
  }

  @override
  void dispose() {
    if (_classListenerAttached) {
      _classProvider?.removeListener(_onSelectedClassChanged);
    }
    super.dispose();
  }

  Future<void> _onPullRefresh() async {
    await _loadStudentsProgress();
  }

  void _onSelectedClassChanged() {
    if (!mounted || _classProvider == null) return;
    final nextKey = _classProvider!.selectedClass?.id ?? _allClassesKey;
    final prevKey = _lastLoadedClassId ?? _allClassesKey;
    if (nextKey == prevKey) return;
    _loadStudentsProgress();
  }

  Future<void> _loadStudentsProgress() async {
    final classProvider = Provider.of<ClassProvider>(context, listen: false);
    final selectedClassId = classProvider.selectedClass?.id;

    setState(() {
      _isLoading = true;
      _studentsProgress = [];
      _studentsOnlineStatus = {};
    });

    try {
      _resolvedStudentTopicKeys =
          await _supabaseService.getResolvedStudentTopicKeys();

      // 根據選中的班級篩選學生
      final progress = await _supabaseService.getAllStudentsProgress(classId: selectedClassId);
      
      // 獲取所有學生的登入狀態
      final studentIds = progress.map((s) => s['student_id'] as String).toList();
      _studentsOnlineStatus = await _supabaseService.getStudentsOnlineStatus(studentIds);
      _studentsAiUsageStatus = await _supabaseService.getStudentsAiUsageStatus(studentIds);
      print('Dashboard: Received ${progress.length} students');

      // 獲取所有課程，建立 ID 到課程名稱的映射
      final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
      await grammarTopicProvider.loadTopics(classId: selectedClassId);
      final topics = grammarTopicProvider.topics;
      final topicMap = <String, String>{};
      final topicTargetMap = <String, int>{};
      for (var topic in topics) {
        topicMap[topic.id] = topic.title;
        topicTargetMap[topic.id] = topic.completionQuestionTarget;
      }
      _topicCompletionTargets = topicTargetMap;
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
          final topicQuestions = questions
              .where((q) => q.grammarTopicId == currentGrammarTopicId)
              .toList();
          final isStage4Completed = topicQuestions.any(
            (q) => q.completedStages?.containsKey(4) ?? false,
          );
          final totalQuestions = topicQuestions.length;
          final topicCompletionTarget =
              _topicCompletionTargets[currentGrammarTopicId] ?? 5;
          final resolvedKey = '$studentId:$currentGrammarTopicId';
          final hasManualCompletion =
              _resolvedStudentTopicKeys.contains(resolvedKey);
          final isCompletedByTarget = totalQuestions >= topicCompletionTarget;
          final isOverallCompleted =
              isStage4Completed || hasManualCompletion || isCompletedByTarget;
          
          final stageDuration = latestQuestion.updatedAt != null
              ? DateTime.now().difference(latestQuestion.updatedAt!)
              : DateTime.now().difference(latestQuestion.createdAt);
          
          double avgStage = 0;
          if (totalQuestions > 0) {
            for (var question in topicQuestions) {
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
            'has_manual_completion': hasManualCompletion,
            'is_completed_by_target': isCompletedByTarget,
            'is_overall_completed': isOverallCompleted,
            'completion_question_target': topicCompletionTarget,
            'has_ai_helper_usage': _studentsAiUsageStatus[studentId] ?? false,
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
            'has_manual_completion': false,
            'is_completed_by_target': false,
            'is_overall_completed': false,
            'completion_question_target': 5,
            'has_ai_helper_usage': _studentsAiUsageStatus[studentId] ?? false,
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
        _lastLoadedClassId = selectedClassId;
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

  bool _isInactiveOverOneMinute(Map<String, dynamic> student) {
    final lastActivity = student['last_activity'] as String?;
    if (lastActivity == null || lastActivity.isEmpty) return true;
    final activityTime = DateTime.parse(lastActivity);
    return DateTime.now().difference(activityTime).inMinutes >= 1;
  }

  bool _isOffline(Map<String, dynamic> student) {
    final studentId = student['student_id'] as String?;
    if (studentId == null) return true;
    return !(_studentsOnlineStatus[studentId] ?? false);
  }

  bool _hasAlert(Map<String, dynamic> student) {
    if (student['is_overall_completed'] == true) {
      return false;
    }
    return _isOffline(student) || _isInactiveOverOneMinute(student);
  }

  String _alertReason(Map<String, dynamic> student) {
    final parts = <String>[];
    if (_isOffline(student)) parts.add('未登入');
    if (_isInactiveOverOneMinute(student)) parts.add('逾 1 分鐘未活動');
    return parts.isEmpty ? '—' : parts.join('、');
  }

  String _completionReason(Map<String, dynamic> student) {
    if (student['has_manual_completion'] == true) return '手動標記完成';
    if (student['is_stage_4_completed'] == true) return '已完成階段四';
    if (student['is_completed_by_target'] == true) {
      final target = student['completion_question_target'] as int? ?? 5;
      final total = student['total_questions'] as int? ?? 0;
      return '題數達標（$total / $target 題）';
    }
    return '已完成';
  }

  void _showStudentListDialog({
    required String title,
    required List<Map<String, dynamic>> students,
    required String emptyMessage,
    required String Function(Map<String, dynamic> student) subtitleFor,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: students.isEmpty
              ? Center(child: Text(emptyMessage))
              : ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final name =
                        student['student_name'] as String? ?? '未設定姓名';
                    final idNumber = student['student_id_number'] as String?;
                    final topicName =
                        student['current_grammar_topic_name'] as String?;
                    return ListTile(
                      title: Text(name),
                      subtitle: Text(
                        [
                          if (idNumber != null && idNumber.isNotEmpty)
                            '學號：$idNumber',
                          if (topicName != null && topicName.isNotEmpty)
                            '課程：$topicName',
                          subtitleFor(student),
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardStatDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.65),
    );
  }

  Widget _buildDashboardStatCell({
    required int count,
    required String label,
    VoidCallback? onTap,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return Center(child: content);
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Center(child: content),
      ),
    );
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
    bool isInactive,
    bool isOffline,
  ) {
    final totalQuestions = student['total_questions'] as int? ?? 0;
    final completionTarget = student['completion_question_target'] as int? ?? 5;
    final hasAiUsage = student['has_ai_helper_usage'] == true;
    final isCompletedByTarget = student['is_completed_by_target'] == true;
    final hasManualCompletion = student['has_manual_completion'] == true;
    final isOverallCompleted = student['is_overall_completed'] == true;

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
                            if (student['last_login_at'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '最近登入: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(student['last_login_at']))}',
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
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.numbers,
                        label: '完成標準題數',
                        value: '$completionTarget 題',
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.quiz_outlined,
                        label: '已完成題數',
                        value: '$totalQuestions 題',
                        color: Colors.indigo,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.smart_toy_outlined,
                        label: 'AI 小幫手使用',
                        value: hasAiUsage ? '有使用' : '未使用',
                        color: hasAiUsage ? Colors.green : Colors.grey,
                      ),
                      if (isOverallCompleted) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.verified,
                          label: '完成狀態',
                          value: hasManualCompletion
                              ? '學生手動確認完成'
                              : (isCompletedByTarget
                                  ? '已達完成標準題數'
                                  : '已完成階段四'),
                          color: Colors.green,
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
                              if (isOffline)
                                Text(
                                  '該學生目前未登入',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red[700],
                                  ),
                                ),
                              if (isInactive)
                                Text(
                                  '該學生逾 1 分鐘未活動',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red[700],
                                  ),
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    if (studentId == null) return;
                                    final topicId =
                                        student['current_grammar_topic_id']
                                            as String?;
                                    if (topicId == null ||
                                        topicId.trim().isEmpty) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('此學生目前無課程可標記'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                    
                                    try {
                                      await _supabaseService
                                          .markStudentAttentionResolved(
                                        studentId,
                                        grammarTopicId: topicId,
                                      );
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
                                    '老師標記完成',
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
    final classProvider = Provider.of<ClassProvider>(context);

    return Scaffold(
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
            TeacherTabTopBar(
              selectedClass: classProvider.selectedClass,
              onClassSelected: (classId) async {
                Provider.of<ClassProvider>(context, listen: false)
                    .selectClassById(classId);
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '設定課程完成標準題數',
                    icon: const Icon(Icons.tune),
                    onPressed: () {
                      _showCompletionTargetDialog(context);
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
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onPullRefresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(height: _isTopPanelCollapsed ? 8 : 8),
                    ),
                    if (!_isTopPanelCollapsed)
                      SliverToBoxAdapter(child: _buildDashboardStatsCard()),
                    if (!_isTopPanelCollapsed)
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    if (_isLoading)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: _CuteLoadingIndicator(
                            label: '整理資料中...',
                          ),
                        ),
                      )
                    else if (_studentsProgress.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            '尚無學生資料',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: MediaQuery.of(context).padding.bottom + 100,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                            final student = _studentsProgress[index];
                            final hasAlert = _hasAlert(student);
                            final isInactive = _isInactiveOverOneMinute(student);
                            final isOffline = _isOffline(student);
                            final stage = student['current_stage'] as int? ?? 1;
                            final avgStage = student['average_stage'] as double? ?? 1.0;
                            final stageColor = _getStageColor(stage.round());
                            final stageDistribution = student['stage_distribution'] as Map<int, int>? ?? {};
                            final completedStagesCount = student['completed_stages_count'] as Map<int, int>? ?? {};

                            return InkWell(
                              onTap: () {
                                _showStudentDetailDialog(context, student, stageColor, stageDistribution, completedStagesCount, avgStage, hasAlert, isInactive, isOffline);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: hasAlert
                                      ? const Color(0xFFFFEBEE)
                                      : Colors.white.withValues(alpha: 0.82),
                                  borderRadius: BorderRadius.circular(16),
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
                                        if (student['last_login_at'] != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '最近登入: ${DateFormat('MM-dd HH:mm').format(DateTime.parse(student['last_login_at']))}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Text(
                                          'AI 小幫手: ${student['has_ai_helper_usage'] == true ? '有使用' : '未使用'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
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
                                        if (student['is_overall_completed'] == true) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.verified,
                                                size: 16,
                                                color: Colors.green[700],
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  student['has_manual_completion'] == true
                                                      ? '學生已手動確認完成'
                                                      : '已達完成條件',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.green[700],
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else if (hasAlert) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.warning_amber_rounded,
                                                size: 16,
                                                color: Colors.red.shade800,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  _alertReason(student),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.red.shade900,
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
                            childCount: _studentsProgress.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildDashboardStatsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildDashboardStatCell(
                count: _studentsProgress.length,
                label: '總學生數',
              ),
            ),
            _buildDashboardStatDivider(),
            Expanded(
              child: _buildDashboardStatCell(
                count: _studentsProgress.where((s) => _hasAlert(s)).length,
                label: '需要關注',
                onTap: () {
                  final list =
                      _studentsProgress.where((s) => _hasAlert(s)).toList();
                  _showStudentListDialog(
                    title: '需要關注的學生',
                    students: list,
                    emptyMessage: '目前沒有需要關注的學生',
                    subtitleFor: _alertReason,
                  );
                },
              ),
            ),
            _buildDashboardStatDivider(),
            Expanded(
              child: _buildDashboardStatCell(
                count: _studentsOnlineStatus.values
                    .where((isOnline) => isOnline)
                    .length,
                label: '登入中',
              ),
            ),
            _buildDashboardStatDivider(),
            Expanded(
              child: _buildDashboardStatCell(
                count: _studentsProgress
                    .where((s) => s['is_overall_completed'] == true)
                    .length,
                label: '已完成',
                onTap: () {
                  final list = _studentsProgress
                      .where((s) => s['is_overall_completed'] == true)
                      .toList();
                  _showStudentListDialog(
                    title: '已完成的學生',
                    students: list,
                    emptyMessage: '目前沒有已完成的學生',
                    subtitleFor: _completionReason,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCompletionTargetDialog(BuildContext context) async {
    final selectedClassId =
        Provider.of<ClassProvider>(context, listen: false).selectedClass?.id;
    if (selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先選擇班級後再設定課程完成標準'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final grammarTopicProvider =
        Provider.of<GrammarTopicProvider>(context, listen: false);
    await grammarTopicProvider.loadTopics(classId: selectedClassId);
    final topics = grammarTopicProvider.topics;
    if (topics.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('此班級目前沒有課程可設定'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String selectedTopicId = topics.first.id;
    final controller = TextEditingController(
      text: (_topicCompletionTargets[selectedTopicId] ??
              topics.first.completionQuestionTarget)
          .toString(),
    );
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('設定課程完成標準題數'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedTopicId,
                decoration: const InputDecoration(
                  labelText: '課程',
                ),
                items: topics
                    .map(
                      (topic) => DropdownMenuItem<String>(
                        value: topic.id,
                        child: Text(topic.title),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    selectedTopicId = value;
                    final target = _topicCompletionTargets[selectedTopicId] ??
                        topics
                            .firstWhere((t) => t.id == selectedTopicId)
                            .completionQuestionTarget;
                    controller.text = target.toString();
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '完成標準（題數）',
                  hintText: '請輸入大於 0 的整數',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed == null || parsed <= 0) return;
                Navigator.of(dialogContext).pop({
                  'topicId': selectedTopicId,
                  'target': parsed,
                });
              },
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final ok = await _supabaseService.updateGrammarTopicCompletionQuestionTarget(
      result['topicId'] as String,
      result['target'] as int,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '完成標準已更新' : '完成標準更新失敗'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    if (ok) {
      await _loadStudentsProgress();
    }
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


