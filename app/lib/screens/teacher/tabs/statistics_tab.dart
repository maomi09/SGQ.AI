import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/grammar_topic_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../models/grammar_topic_model.dart';
import '../../../models/student_topic_usage_stats_model.dart';
import '../../../utils/error_handler.dart';
import '../../../widgets/teacher_tab_top_bar.dart';
import '../../../widgets/teacher_badge_dialogs.dart';
import '../../../widgets/statistics_more_menu_button.dart';
import '../../../widgets/teacher_student_search_field.dart';

class StatisticsTab extends StatefulWidget {
  const StatisticsTab({super.key});

  @override
  State<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<StatisticsTab> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>>? _individualStats;
  List<Map<String, dynamic>>? _filteredStats;
  Map<String, List<StudentTopicUsageStatsModel>> _topicUsageByStudent = {};
  Map<String, String> _topicTitleById = {};
  List<String> _classTopicIds = [];
  /// 顯示用課程 id -> 同標題之所有 grammar_topic id（合併統計）
  Map<String, List<String>> _topicIdGroupsByCanonicalId = {};
  /// 顯示用課程 id -> 所屬班級 id
  Map<String, String?> _canonicalTopicClassId = {};
  bool _isLoading = true;

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
      if (mounted) await _loadStatistics();
    });
  }

  @override
  void dispose() {
    if (_classListenerAttached) {
      _classProvider?.removeListener(_onSelectedClassChanged);
    }
    _searchController.dispose();
    super.dispose();
  }

  void _onSelectedClassChanged() {
    if (!mounted || _classProvider == null) return;
    final nextKey = _classProvider!.selectedClass?.id ?? _allClassesKey;
    final prevKey = _lastLoadedClassId ?? _allClassesKey;
    if (nextKey == prevKey) return;
    _searchController.clear();
    _loadStatistics();
  }

  Future<void> _onPullRefresh() async {
    await _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    final selectedClassId =
        Provider.of<ClassProvider>(context, listen: false).selectedClass?.id;

    setState(() {
      _isLoading = true;
      _individualStats = [];
      _filteredStats = [];
      _topicUsageByStudent = {};
      _classTopicIds = [];
      _topicTitleById = {};
      _topicIdGroupsByCanonicalId = {};
      _canonicalTopicClassId = {};
    });

    try {
      final grammarTopicProvider =
          Provider.of<GrammarTopicProvider>(context, listen: false);
      if (selectedClassId != null) {
        await grammarTopicProvider.loadTopics(classId: selectedClassId);
      } else {
        await grammarTopicProvider.loadTopics();
      }
      final classTopics = selectedClassId != null
          ? grammarTopicProvider.topics
              .where((t) => t.classId == selectedClassId)
              .toList()
          : grammarTopicProvider.topics;
      final deduped = _dedupeClassTopicsForDisplay(classTopics);
      final topicTitleById = deduped.titleById;
      final classTopicIds = deduped.canonicalTopicIds;
      final topicIdGroupsByCanonicalId = deduped.idGroupsByCanonicalId;
      final canonicalTopicClassId = deduped.classIdByCanonicalId;

      final allStudentsProgress =
          await _supabaseService.getAllStudentsProgress(classId: selectedClassId);

      final topicUsageByStudent =
          await _supabaseService.getStudentTopicUsageStatsForClass(
        classId: selectedClassId,
        topicIds: classTopicIds.isEmpty ? null : classTopicIds,
      );

      setState(() {
        _topicTitleById = topicTitleById;
        _classTopicIds = classTopicIds;
        _topicIdGroupsByCanonicalId = topicIdGroupsByCanonicalId;
        _canonicalTopicClassId = canonicalTopicClassId;
        _topicUsageByStudent = topicUsageByStudent;
        _individualStats = allStudentsProgress;
        _filteredStats = allStudentsProgress;
        _isLoading = false;
        _lastLoadedClassId = selectedClassId;
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
            content: Text(ErrorHandler.getSafeErrorMessage(e)),
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
  Widget build(BuildContext context) {
    final classProvider = Provider.of<ClassProvider>(context);
    final viewInsets = MediaQuery.of(context).viewInsets;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
            TeacherTabTopBar(
              selectedClass: classProvider.selectedClass,
              onClassSelected: (classId) async {
                Provider.of<ClassProvider>(context, listen: false)
                    .selectClassById(classId);
              },
              trailing: StatisticsMoreMenuButton(
                onAward: () {
                  showTeacherAwardBadgeDialog(
                    context: context,
                    supabaseService: _supabaseService,
                    studentsProgress: _individualStats ?? [],
                  );
                },
                onLeaderboard: () {
                  showClassBadgeLeaderboardDialog(
                    context: context,
                    supabaseService: _supabaseService,
                  );
                },
                onProgress: () => _showCourseProgressDialog(context),
              ),
            ),
            TeacherStudentSearchBar(
              controller: _searchController,
              onChanged: _filterStudents,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onPullRefresh,
                child: _buildStatisticsScrollBody(
                  viewInsets: viewInsets,
                  bottomPadding: bottomPadding,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStatisticsScrollBody({
    required EdgeInsets viewInsets,
    required double bottomPadding,
  }) {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          const Center(
            child: _CuteLoadingIndicator(
              label: '分析數據中...',
            ),
          ),
        ],
      );
    }

    if (_individualStats == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '無法載入數據',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '請檢查網絡連接後，向下拉動即可重新載入',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: viewInsets.bottom + bottomPadding + 100,
      ),
      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                final studentId = student['student_id'] as String;
                                final studentName =
                                    student['student_name']?.toString().isNotEmpty ==
                                            true
                                        ? student['student_name'] as String
                                        : '未設定姓名';
                                final topicStats =
                                    _topicUsageByStudent[studentId] ?? [];
                                final statsByTopicId = {
                                  for (final s in topicStats)
                                    s.grammarTopicId: s,
                                };
                                final studentTopicIds =
                                    _topicIdsForStudent(student);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      childrenPadding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        16,
                                      ),
                                      leading: Icon(
                                        Icons.person,
                                        color: Colors.green.shade600,
                                      ),
                                      title: Text(
                                        studentName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                      subtitle: student['student_id_number']
                                                  ?.toString()
                                                  .isNotEmpty ==
                                              true
                                          ? Text(
                                              '學號: ${student['student_id_number']}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            )
                                          : null,
                                      children: _classTopicIds.isEmpty
                                          ? [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Text(
                                                  '此班級尚無課程',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ),
                                            ]
                                          : studentTopicIds.isEmpty
                                              ? [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8),
                                                    child: Text(
                                                      student['class_id']
                                                                  ?.toString()
                                                                  .isNotEmpty ==
                                                              true
                                                          ? '此學生所屬班級尚無課程'
                                                          : '此學生尚未分配班級，無法顯示課程數據',
                                                      style: TextStyle(
                                                        color:
                                                            Colors.grey[600],
                                                      ),
                                                    ),
                                                  ),
                                                ]
                                              : studentTopicIds
                                              .map((topicId) {
                                              final relatedIds =
                                                  _topicIdGroupsByCanonicalId[
                                                          topicId] ??
                                                      [topicId];
                                              final stats =
                                                  _mergeTopicStatsForStudent(
                                                studentId: studentId,
                                                topicIds: relatedIds,
                                                statsByTopicId: statsByTopicId,
                                              );
                                              return _buildTopicUsageBlock(
                                                topicTitle: _topicTitleById[
                                                        topicId] ??
                                                    '未知課程',
                                                stats: stats,
                                              );
                                            })
                                              .toList(),
                                    ),
                                  ),
                                );
                              }),
                          const SizedBox(height: 20),
                        ],
                      ),
    );
  }

  Future<void> _showCourseProgressDialog(BuildContext context) async {
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
    final classId =
        Provider.of<ClassProvider>(context, listen: false).selectedClass?.id;
    if (classId != null) {
      await grammarTopicProvider.loadTopics(classId: classId);
    } else {
      await grammarTopicProvider.loadTopics();
    }
    final topics = classId != null
        ? grammarTopicProvider.topics
            .where((t) => t.classId == classId)
            .toList()
        : grammarTopicProvider.topics;

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
                    items: topics.map((topic) {
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
                    future: _loadCourseStudentsProgress(
                      selectedTopicId!,
                      classId: classId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: _CuteLoadingIndicator(
                              label: '小貓讀取課程進度中...',
                            ),
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
                                color: Colors.white.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(8),
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

  Future<List<Map<String, dynamic>>> _loadCourseStudentsProgress(
    String grammarTopicId, {
    String? classId,
  }) async {
    try {
      final allStudents =
          await _supabaseService.getAllStudentsProgress(classId: classId);
      final studentIds = allStudents.map((s) => s['student_id'] as String).toList();
      
      // Batch query all questions for all students (optimized: 1 query instead of N queries)
      final allQuestionsByStudent = await _supabaseService.getAllQuestionsForStudents(studentIds);
      
      // Build result list
      final List<Map<String, dynamic>> result = [];
      
      for (var student in allStudents) {
        final studentId = student['student_id'] as String;
        final allQuestions = allQuestionsByStudent[studentId] ?? [];
        
        // Filter questions by grammar topic
        final studentQuestions = allQuestions.where((q) => q.grammarTopicId == grammarTopicId).toList();
        
        if (studentQuestions.isEmpty) {
          continue;
        }
        
        // Sort by updated_at descending
        studentQuestions.sort((a, b) {
          final aTime = a.updatedAt ?? a.createdAt;
          final bTime = b.updatedAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });
        
        final latestQuestion = studentQuestions.first;
        final currentStage = latestQuestion.stage;
        final isStage4Completed = latestQuestion.completedStages?.containsKey(4) ?? false;
        
        result.add({
          'student_id': studentId,
          'student_name': student['student_name'] as String? ?? '',
          'student_id_number': student['student_id_number'] as String? ?? '',
          'current_stage': currentStage,
          'is_stage_4_completed': isStage4Completed,
        });
      }
      
      // Sort by stage (stage 4 first, then 3, 2, 1)
      result.sort((a, b) {
        final stageA = a['current_stage'] as int;
        final stageB = b['current_stage'] as int;
        final completedA = a['is_stage_4_completed'] == true;
        final completedB = b['is_stage_4_completed'] == true;
        
        if (completedA && !completedB) return -1;
        if (!completedA && completedB) return 1;
        
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

  Widget _buildTopicUsageBlock({
    required String topicTitle,
    required StudentTopicUsageStatsModel stats,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topicTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 10),
          _buildStatRow(
            '平均每題完成時間',
            _formatDurationSeconds(stats.averageQuestionCompletionSeconds),
          ),
          const SizedBox(height: 6),
          _buildStatRow(
            '修改題目次數',
            '${stats.questionEditCount} 次',
          ),
          const SizedBox(height: 6),
          _buildStatRow('登入次數', '${stats.loginCount} 次'),
          const SizedBox(height: 6),
          _buildStatRow(
            '平均單次使用時間',
            '${stats.averageSessionMinutes.toStringAsFixed(1)} 分鐘',
          ),
          const SizedBox(height: 6),
          _buildStatRow(
            '文法重點瀏覽',
            '${stats.grammarKeyPointViewCount} 次',
          ),
          const SizedBox(height: 6),
          _buildStatRow(
            '出題重點瀏覽',
            '${stats.reminderViewCount} 次',
          ),
          if (stats.questionCompletionCount > 0) ...[
            const SizedBox(height: 6),
            _buildStatRow(
              '階段完成次數',
              '${stats.questionCompletionCount} 次',
            ),
          ],
        ],
      ),
    );
  }

  String _formatDurationSeconds(double seconds) {
    if (seconds <= 0) return '尚無資料';
    final total = seconds.round();
    if (total < 60) return '$total 秒';
    final minutes = total ~/ 60;
    final remain = total % 60;
    if (minutes < 60) {
      return remain > 0 ? '$minutes 分 $remain 秒' : '$minutes 分鐘';
    }
    final hours = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '$hours 小時 $m 分' : '$hours 小時';
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

  static String _topicDedupeKey(GrammarTopicModel topic) {
    final classPart = topic.classId ?? '';
    return '$classPart::${topic.title.trim()}';
  }

  /// 同班級、同標題若有多筆課程，只保留一張卡片（以最新建立的為代表）。
  /// 不同班級即使標題相同也不合併，避免學生看到非自己班級的課程數據。
  ({
    Map<String, String> titleById,
    List<String> canonicalTopicIds,
    Map<String, List<String>> idGroupsByCanonicalId,
    Map<String, String?> classIdByCanonicalId,
  }) _dedupeClassTopicsForDisplay(List<GrammarTopicModel> classTopics) {
    final seenIds = <String>{};
    final uniqueById = <GrammarTopicModel>[];
    for (final t in classTopics) {
      if (seenIds.add(t.id)) {
        uniqueById.add(t);
      }
    }

    final canonicalByKey = <String, GrammarTopicModel>{};
    final idsByKey = <String, List<String>>{};
    for (final t in uniqueById) {
      final key = _topicDedupeKey(t);
      idsByKey.putIfAbsent(key, () => []).add(t.id);
      final current = canonicalByKey[key];
      if (current == null || t.createdAt.isAfter(current.createdAt)) {
        canonicalByKey[key] = t;
      }
    }

    final canonicalTopics = canonicalByKey.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return (
      titleById: {for (final t in canonicalTopics) t.id: t.title},
      canonicalTopicIds: canonicalTopics.map((t) => t.id).toList(),
      idGroupsByCanonicalId: {
        for (final entry in canonicalByKey.entries)
          entry.value.id: List<String>.from(idsByKey[entry.key]!),
      },
      classIdByCanonicalId: {
        for (final t in canonicalTopics) t.id: t.classId,
      },
    );
  }

  /// 僅顯示與學生 [class_id] 相同班級的課程卡片。
  List<String> _topicIdsForStudent(Map<String, dynamic> student) {
    final studentClassId = student['class_id']?.toString();
    if (studentClassId == null || studentClassId.isEmpty) {
      return [];
    }
    return _classTopicIds
        .where(
          (topicId) => _canonicalTopicClassId[topicId] == studentClassId,
        )
        .toList();
  }

  StudentTopicUsageStatsModel _mergeTopicStatsForStudent({
    required String studentId,
    required List<String> topicIds,
    required Map<String, StudentTopicUsageStatsModel> statsByTopicId,
  }) {
    StudentTopicUsageStatsModel? merged;
    for (final topicId in topicIds) {
      final stats = statsByTopicId[topicId];
      if (stats == null) continue;
      if (merged == null) {
        merged = stats;
        continue;
      }
      merged = StudentTopicUsageStatsModel(
        studentId: studentId,
        grammarTopicId: topicIds.first,
        questionCompletionCount:
            merged.questionCompletionCount + stats.questionCompletionCount,
        totalQuestionCompletionSeconds:
            merged.totalQuestionCompletionSeconds +
                stats.totalQuestionCompletionSeconds,
        questionEditCount:
            merged.questionEditCount + stats.questionEditCount,
        loginCount: merged.loginCount + stats.loginCount,
        totalSessionMinutes:
            merged.totalSessionMinutes + stats.totalSessionMinutes,
        grammarKeyPointViewCount: merged.grammarKeyPointViewCount +
            stats.grammarKeyPointViewCount,
        reminderViewCount:
            merged.reminderViewCount + stats.reminderViewCount,
      );
    }
    return merged ??
        StudentTopicUsageStatsModel(
          studentId: studentId,
          grammarTopicId: topicIds.first,
        );
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


