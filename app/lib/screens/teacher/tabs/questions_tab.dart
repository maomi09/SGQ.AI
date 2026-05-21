import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/grammar_topic_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../models/question_model.dart';
import '../../../utils/error_handler.dart';
import '../../../widgets/teacher_tab_top_bar.dart';
import '../../../widgets/teacher_student_search_field.dart';
import '../student_questions_screen.dart';

class QuestionsTab extends StatefulWidget {
  const QuestionsTab({super.key});

  @override
  State<QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<QuestionsTab> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  ClassProvider? _classProvider;
  String? _lastLoadedClassId;
  bool _classListenerAttached = false;
  static const Object _allClassesKey = Object();

  List<Map<String, dynamic>> _students = [];
  Map<String, List<QuestionModel>> _questionsByStudentId = {};
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isLoading = true;

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
      if (mounted) await _loadData();
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
    _loadData();
  }

  void _applyStudentFilter([String? queryOverride]) {
    final query = (queryOverride ?? _searchController.text).trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredStudents = List<Map<String, dynamic>>.from(_students);
      });
      return;
    }
    setState(() {
      _filteredStudents = _students.where((student) {
        final name = (student['student_name'] as String? ?? '').toLowerCase();
        final idNumber =
            (student['student_id_number'] as String? ?? '').toLowerCase();
        return name.contains(query) || idNumber.contains(query);
      }).toList();
    });
  }

  Future<void> _onPullRefresh() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    final classProvider = Provider.of<ClassProvider>(context, listen: false);
    final selectedClassId = classProvider.selectedClass?.id;

    setState(() => _isLoading = true);

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
      final allowedTopicIds = classTopics.map((t) => t.id).toSet();
      final students =
          await _supabaseService.getAllStudentsProgress(classId: selectedClassId);
      final studentIds =
          students.map((s) => s['student_id'] as String).toList();

      final questionsByStudent =
          await _supabaseService.getAllQuestionsForStudents(studentIds);

      final Map<String, List<QuestionModel>> grouped = {};
      for (final student in students) {
        final studentId = student['student_id'] as String;
        final raw = questionsByStudent[studentId] ?? [];
        final filtered = selectedClassId != null
            ? raw.where((q) => allowedTopicIds.contains(q.grammarTopicId)).toList()
            : raw;
        grouped[studentId] = filtered;
      }

      setState(() {
        _students = students;
        _questionsByStudentId = grouped;
        _isLoading = false;
        _lastLoadedClassId = selectedClassId;
      });
      _applyStudentFilter();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getSafeErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openStudentDetail(Map<String, dynamic> student) {
    final studentId = student['student_id'] as String;
    final questionCount = _questionsByStudentId[studentId]?.length ?? 0;
    if (questionCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('此學生尚無題目'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final name = student['student_name'] as String? ?? '未設定姓名';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentQuestionsScreen(
          studentId: studentId,
          studentName: name,
          studentIdNumber: student['student_id_number'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classProvider = Provider.of<ClassProvider>(context);
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
                trailing: const SizedBox.shrink(),
              ),
              TeacherStudentSearchBar(
                controller: _searchController,
                onChanged: _applyStudentFilter,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onPullRefresh,
                  child: _buildStudentList(bottomPadding),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentList(double bottomPadding) {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_filteredStudents.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Center(
            child: Text(
              _students.isEmpty ? '此班級尚無學生' : '找不到符合條件的學生',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding + 100),
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) {
        final student = _filteredStudents[index];
        final studentId = student['student_id'] as String;
        final name = student['student_name'] as String? ?? '未設定姓名';
        final idNumber = student['student_id_number'] as String?;
        final questionCount = _questionsByStudentId[studentId]?.length ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          color: Colors.white.withValues(alpha: 0.82),
          child: InkWell(
            onTap: () => _openStudentDetail(student),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        if (idNumber != null && idNumber.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '學號：$idNumber',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          questionCount > 0
                              ? '共 $questionCount 題 · 點擊查看題目與對話'
                              : '尚無題目',
                          style: TextStyle(
                            fontSize: 13,
                            color: questionCount > 0
                                ? Colors.green.shade700
                                : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
