import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/grammar_topic_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../models/question_model.dart';
import '../../teacher/student_questions_screen.dart';

class StatisticsTab extends StatefulWidget {
  const StatisticsTab({super.key});

  @override
  State<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<StatisticsTab> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _overallStats;
  List<Map<String, dynamic>>? _individualStats;
  List<Map<String, dynamic>>? _filteredStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allStudentsProgress = await _supabaseService.getAllStudentsProgress();

      Map<String, int> weeklyLogins = {};
      int totalQuestions = 0;
      int totalUsageTime = 0;
      double totalSessionDuration = 0;
      int sessionCount = 0;

      for (var student in allStudentsProgress) {
        final studentId = student['student_id'] as String;
        final stats = await _supabaseService.getStudentStatistics(studentId);
        
        weeklyLogins[studentId] = stats['weekly_login_frequency'] as int;
        totalQuestions += stats['total_questions'] as int;
        
        // 確保 total_usage_time 是非負數
        final usageTime = stats['total_usage_time'] as int;
        totalUsageTime += usageTime > 0 ? usageTime : 0;
        
        // 安全地轉換 average_session_duration（可能是 int 或 double）
        final avgDuration = stats['average_session_duration'];
        final avgDurationValue = avgDuration is double 
            ? avgDuration 
            : (avgDuration as num).toDouble();
        
        // 確保平均時長是非負數
        if (avgDurationValue > 0) {
          totalSessionDuration += avgDurationValue;
          sessionCount++;
        }
      }

      setState(() {
        _overallStats = {
          'total_students': allStudentsProgress.length,
          'total_questions': totalQuestions,
          'total_usage_time': totalUsageTime,
          'average_session_duration': sessionCount > 0 ? totalSessionDuration / sessionCount : 0,
          'weekly_logins': weeklyLogins,
        };
        _individualStats = allStudentsProgress;
        _filteredStats = allStudentsProgress;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Error loading statistics: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入數據失敗: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _filterStudents(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredStats = _individualStats;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredStats = _individualStats?.where((student) {
        final name = (student['student_name'] as String? ?? '').toLowerCase();
        final idNumber = (student['student_id_number'] as String? ?? '').toLowerCase();
        return name.contains(lowerQuery) || idNumber.contains(lowerQuery);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.green.shade400,
                          child: Text(
                            user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'T',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '數據統計',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                '查看學習數據分析',
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
                        onPressed: _loadStatistics,
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
            // 內容區域
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (_overallStats == null && _individualStats == null)
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '無法載入數據',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '請檢查網絡連接或稍後再試',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _loadStatistics,
                                icon: const Icon(Icons.refresh),
                                label: const Text('重新載入'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_overallStats != null) ...[
                            Container(
                              padding: const EdgeInsets.all(24),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '整體統計',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildStatCard(
                                    icon: Icons.people,
                                    label: '總學生數',
                                    value: '${_overallStats!['total_students']}',
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildStatCard(
                                    icon: Icons.quiz,
                                    label: '總題數',
                                    value: '${_overallStats!['total_questions']}',
                                    color: Colors.green,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildStatCard(
                                    icon: Icons.timer,
                                    label: '總使用時長',
                                    value: '${math.max(0, _overallStats!['total_usage_time'] as int)} 分鐘',
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildStatCard(
                                    icon: Icons.access_time,
                                    label: '平均單次使用時長',
                                    value: '${math.max(0.0, (_overallStats!['average_session_duration'] as num).toDouble()).toStringAsFixed(1)} 分鐘',
                                    color: Colors.purple,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          const Text(
                            '個別學生統計',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 搜尋框
                          Container(
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
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _searchController,
                              builder: (context, value, child) {
                                return TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: '搜尋學生（姓名或學號）',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: value.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _searchController.clear();
                                              _filterStudents('');
                                            },
                                          )
                                        : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  onChanged: _filterStudents,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_filteredStats != null)
                            if (_filteredStats!.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Text(
                                    '找不到符合搜尋條件的學生',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              )
                            else
                              ..._filteredStats!.map((student) {
                                return FutureBuilder<Map<String, dynamic>>(
                                future: _supabaseService.getStudentStatistics(student['student_id'] as String),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const SizedBox.shrink();
                                  }
                                  final stats = snapshot.data!;
                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => StudentQuestionsScreen(
                                            studentId: student['student_id'] as String,
                                            studentName: student['student_name']?.toString().isNotEmpty == true
                                                ? student['student_name'] as String
                                                : '未設定姓名',
                                            studentIdNumber: student['student_id_number'] as String?,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
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
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.green.shade600,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    student['student_name']?.toString().isNotEmpty == true
                                                        ? student['student_name'] as String
                                                        : '未設定姓名',
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
                                                        fontSize: 14,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildStatRow('每周登入頻率', '${math.max(0, stats['weekly_login_frequency'] as int)} 次'),
                                        const SizedBox(height: 8),
                                        _buildStatRow('單次使用時長', '${math.max(0.0, (stats['average_session_duration'] as num).toDouble()).toStringAsFixed(1)} 分鐘'),
                                        const SizedBox(height: 8),
                                        _buildStatRow('練習題數', '${math.max(0, stats['total_questions'] as int)}'),
                                        const SizedBox(height: 8),
                                        _buildStatRow('全期間使用總時長', '${math.max(0, stats['total_usage_time'] as int)} 分鐘'),
                                      ],
                                    ),
                                    ),
                                  );
                                },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCourseProgressDialog(context),
        backgroundColor: Colors.green.shade600,
        icon: const Icon(Icons.assessment, color: Colors.white),
        label: const Text(
          '課程進度',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: _CustomFloatingActionButtonLocation(),
    );
  }

  Future<void> _showCourseProgressDialog(BuildContext context) async {
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
    await grammarTopicProvider.loadTopics();
    
    String? selectedTopicId;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.assessment, color: Colors.green),
                SizedBox(width: 8),
                Text('課程學生完成進度'),
              ],
            ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 課程選擇器
                const Text(
                  '選擇課程：',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButton<String>(
                    value: selectedTopicId,
                    hint: const Text('請選擇課程'),
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: grammarTopicProvider.topics.map((topic) {
                      return DropdownMenuItem<String>(
                        value: topic.id,
                        child: Text(topic.title),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedTopicId = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // 學生進度列表
                if (selectedTopicId != null)
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _loadCourseStudentsProgress(selectedTopicId!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              '該課程尚無學生進度',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }
                      
                      final studentsProgress = snapshot.data!;
                      
                      return SizedBox(
                        height: 400,
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: studentsProgress.length,
                          itemBuilder: (context, index) {
                            final student = studentsProgress[index];
                            final currentStage = student['current_stage'] as int? ?? 1;
                            final isCompleted = student['is_stage_4_completed'] == true;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isCompleted ? Colors.green[50] : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCompleted ? Colors.green : Colors.grey[300]!,
                                  width: isCompleted ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // 階段標籤
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _getStageColor(currentStage),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$currentStage',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 學生信息
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                student['student_name'] as String? ?? '未設定姓名',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1F2937),
                                                ),
                                              ),
                                            ),
                                            if (isCompleted)
                                              const Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 20,
                                              ),
                                          ],
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
                                        const SizedBox(height: 4),
                                        Text(
                                          '階段 $currentStage - ${_getStageName(currentStage)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('關閉'),
            ),
          ],
        );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadCourseStudentsProgress(String grammarTopicId) async {
    try {
      // 獲取所有學生
      final allStudents = await _supabaseService.getAllStudentsProgress();
      
      // 獲取該課程的所有題目
      // 由於 getQuestions 需要 studentId，我們需要獲取所有學生的題目
      // 先獲取所有學生，然後為每個學生獲取該課程的題目
      final List<QuestionModel> allQuestionsList = [];
      
      for (var student in allStudents) {
        final studentId = student['student_id'] as String;
        final questions = await _supabaseService.getQuestions(studentId, grammarTopicId: grammarTopicId);
        allQuestionsList.addAll(questions);
      }
      
      // 建立學生ID到題目的映射
      final Map<String, List<QuestionModel>> questionsByStudent = {};
      for (var question in allQuestionsList) {
        final studentId = question.studentId;
        if (!questionsByStudent.containsKey(studentId)) {
          questionsByStudent[studentId] = [];
        }
        questionsByStudent[studentId]!.add(question);
      }
      
      // 建立結果列表
      final List<Map<String, dynamic>> result = [];
      
      for (var student in allStudents) {
        final studentId = student['student_id'] as String;
        final studentQuestions = questionsByStudent[studentId] ?? [];
        
        if (studentQuestions.isEmpty) {
          continue; // 跳過沒有該課程題目的學生
        }
        
        // 按 updated_at 排序，獲取最新的題目
        final sortedQuestions = List<QuestionModel>.from(studentQuestions);
        sortedQuestions.sort((a, b) {
          final aTime = a.updatedAt ?? a.createdAt;
          final bTime = b.updatedAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });
        
        final latestQuestion = sortedQuestions.first;
        final currentStage = latestQuestion.stage;
        
        // 檢查是否完成階段四
        final isStage4Completed = latestQuestion.completedStages?.containsKey(4) ?? false;
        
        result.add({
          'student_id': studentId,
          'student_name': student['student_name'] as String? ?? '',
          'student_id_number': student['student_id_number'] as String? ?? '',
          'current_stage': currentStage,
          'is_stage_4_completed': isStage4Completed,
        });
      }
      
      // 按階段排序（階段4在前，然後是階段3，以此類推）
      result.sort((a, b) {
        final stageA = a['current_stage'] as int;
        final stageB = b['current_stage'] as int;
        final completedA = a['is_stage_4_completed'] == true;
        final completedB = b['is_stage_4_completed'] == true;
        
        // 已完成階段四的優先顯示
        if (completedA && !completedB) return -1;
        if (!completedA && completedB) return 1;
        
        // 然後按階段降序排序
        return stageB.compareTo(stageA);
      });
      
      return result;
    } catch (e) {
      print('Error loading course students progress: $e');
      return [];
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

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }
}

class _CustomFloatingActionButtonLocation extends FloatingActionButtonLocation {
  const _CustomFloatingActionButtonLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    // 導航欄高度約 80px + 底部間距 16px + SafeArea + 額外安全間距
    // 使用 minInsets.bottom 獲取底部安全區域
    final double safeAreaBottom = scaffoldGeometry.minInsets.bottom;
    final double navigationBarHeight = 80 + 16 + safeAreaBottom + 30;
    final double bottom = scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        navigationBarHeight;
    final double right = scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.floatingActionButtonSize.width -
        16; // 右邊距
    return Offset(right, bottom);
  }
}
