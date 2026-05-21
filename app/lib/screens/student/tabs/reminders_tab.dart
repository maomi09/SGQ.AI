import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/grammar_topic_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../services/student_activity_tracker.dart';
import '../../../models/reminder_model.dart';
import '../../../widgets/cute_loading_indicator.dart';
import '../../../widgets/student_tab_top_bar.dart';
import '../../../widgets/student_ai_assistant_button.dart';

class RemindersTab extends StatefulWidget {
  const RemindersTab({super.key});

  @override
  State<RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends State<RemindersTab> {
  final SupabaseService _supabaseService = SupabaseService();
  List<ReminderModel> _reminders = [];
  bool _isLoading = true;
  String? _lastLoadedTopicId;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _onPullRefresh() async {
    final grammarTopicProvider =
        Provider.of<GrammarTopicProvider>(context, listen: false);
    await grammarTopicProvider.loadTopics(
      classId: grammarTopicProvider.currentClassId,
    );
    if (grammarTopicProvider.selectedTopic != null) {
      await _loadReminders(showLoading: false);
    }
  }

  Future<void> _loadReminders({bool showLoading = true}) async {
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
    if (grammarTopicProvider.selectedTopic == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final reminders = await _supabaseService.getReminders(
        grammarTopicProvider.selectedTopic!.id,
      );
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
      await StudentActivityTracker.instance.trackReminderView(
        grammarTopicProvider.selectedTopic!.id,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context);
    if (grammarTopicProvider.selectedTopic != null) {
      final currentTopicId = grammarTopicProvider.selectedTopic!.id;
      if (currentTopicId != _lastLoadedTopicId) {
        _lastLoadedTopicId = currentTopicId;
        _loadReminders();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context);

    return SafeArea(
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
                await _loadReminders();
              },
              trailing: const StudentAiAssistantIconButton(),
            ),
            // 內容區域（下拉刷新）
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onPullRefresh,
                child: _buildContentScrollView(grammarTopicProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentScrollView(GrammarTopicProvider grammarTopicProvider) {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: const Center(
              child: CuteLoadingIndicator(label: '載入中...'),
            ),
          ),
        ],
      );
    }

    if (grammarTopicProvider.selectedTopic == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
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

    if (_reminders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 100,
        ),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: Center(
              child: Text(
                '此主題尚無出題重點提醒',
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

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 100,
      ),
      itemCount: _reminders.length,
      itemBuilder: (context, index) {
        final reminder = _reminders[index];
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.list,
                      color: Colors.orange.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      reminder.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                reminder.content,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
