import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/ai_chat_pastel_background.dart';

class TeacherStudentChatScreen extends StatefulWidget {
  const TeacherStudentChatScreen({super.key});

  @override
  State<TeacherStudentChatScreen> createState() => _TeacherStudentChatScreenState();
}

class _TeacherStudentChatScreenState extends State<TeacherStudentChatScreen> {
  /// 底部輸入列佔用高度（含留白），供訊息列表避開重疊。
  static const double _messageInputBarExtent = 76;

  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSending = false;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _conversationSummaries = [];
  List<Map<String, dynamic>> _filteredSummaries = [];
  String? _selectedStudentId;
  RealtimeChannel? _realtimeChannel;
  Timer? _pollingTimer;
  bool _isSilentRefreshing = false;
  final Map<String, DateTime> _lastReadAtByStudent = {};
  static const String _teacherReadAtStoragePrefix = 'teacher_chat_last_read_at_';
  static const double _nearBottomThreshold = 120;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _disposeRealtimeSubscription();
    _stopPollingFallback();
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return true;
    return position.maxScrollExtent - position.pixels <= _nearBottomThreshold;
  }

  bool _sameMessages(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i]['id']?.toString() != b[i]['id']?.toString()) {
        return false;
      }
    }
    return true;
  }

  Future<void> _initialize() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    try {
      if (user.role == 'teacher') {
        await _loadPersistedReadStatus(user.id);
        await _loadConversationSummaries();
      } else {
        _selectedStudentId = user.id;
      }

      await _loadMessages();
      _initializeRealtimeSubscription(
        currentUserId: user.id,
        isTeacher: user.role == 'teacher',
      );
      _startPollingFallback(isTeacher: user.role == 'teacher');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getSafeErrorMessage(e)), backgroundColor: Colors.red),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadConversationSummaries() async {
    final list = await _supabaseService.getTeacherStudentConversationSummaries();
    if (!mounted) return;
    setState(() {
      _conversationSummaries = list;
      _filteredSummaries = list;
    });
  }

  void _applySearch(String keyword) {
    final q = keyword.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredSummaries = _conversationSummaries;
      } else {
        _filteredSummaries = _conversationSummaries.where((item) {
          final name = (item['student_name'] as String? ?? '').toLowerCase();
          final content = (item['latest_content'] as String? ?? '').toLowerCase();
          return name.contains(q) || content.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_selectedStudentId == null) {
      setState(() {
        _messages = [];
        _isLoading = false;
      });
      return;
    }
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final messages = await _supabaseService.getTeacherStudentMessages(
        studentId: _selectedStudentId!,
      );
      if (!mounted) return;

      if (silent && _sameMessages(_messages, messages)) {
        return;
      }

      final wasNearBottom = _isNearBottom();
      final hadMoreMessages = messages.length > _messages.length;
      final savedOffset =
          silent && _scrollController.hasClients ? _scrollController.offset : null;

      setState(() {
        _messages = messages;
        if (!silent) {
          _isLoading = false;
        }
      });

      if (!silent) {
        _scrollToBottom(force: true);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          if (wasNearBottom && hadMoreMessages) {
            _scrollToBottom(force: true);
          } else if (savedOffset != null) {
            final maxExtent = _scrollController.position.maxScrollExtent;
            _scrollController.jumpTo(savedOffset.clamp(0.0, maxExtent));
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _isLoading = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getSafeErrorMessage(e)), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openStudentChat(String studentId) async {
    setState(() {
      _selectedStudentId = studentId;
    });
    await _loadMessages();
    _markCurrentChatAsRead();
  }

  void _backToConversationList() {
    _markCurrentChatAsRead();
    setState(() {
      _selectedStudentId = null;
      _messages = [];
    });
  }

  Future<void> _sendMessage({required bool isHandRaise}) async {
    final rawText = _messageController.text.trim();
    if (_selectedStudentId == null) return;

    if (!isHandRaise && rawText.isEmpty) return;
    final text = isHandRaise
        ? (rawText.isEmpty ? '老師，我有問題想請教。' : rawText)
        : rawText;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    setState(() {
      _isSending = true;
    });
    try {
      await _supabaseService.sendTeacherStudentMessage(
        studentId: _selectedStudentId!,
        senderId: user.id,
        senderRole: user.role,
        content: text,
        isHandRaise: isHandRaise,
      );
      if (!mounted) return;
      setState(() {
        _messages.add({
          'student_id': _selectedStudentId,
          'sender_id': user.id,
          'sender_role': user.role,
          'content': text,
          'is_hand_raise': isHandRaise,
          'created_at': DateTime.now().toIso8601String(),
        });
      });
      _scrollToBottom(force: true);
      if (rawText.isNotEmpty) {
        _messageController.clear();
      }
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getSafeErrorMessage(e)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendQuestionForReview() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null || user.role != 'student') return;

    try {
      final questions = await _supabaseService.getQuestions(user.id);
      if (!mounted) return;
      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目前沒有可送審的題目')),
        );
        return;
      }

      final selectedQuestion = await showDialog<dynamic>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('選擇要送審的題目'),
            content: SizedBox(
              width: 500,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: questions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final q = questions[index];
                  final title = q.question.trim();
                  final preview = title.length > 36 ? '${title.substring(0, 36)}...' : title;
                  return ListTile(
                    title: Text(preview),
                    subtitle: Text('階段 ${q.stage}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(dialogContext).pop(q),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
            ],
          );
        },
      );

      if (selectedQuestion == null) return;

      final questionText = selectedQuestion.question?.toString().trim() ?? '';
      final answerText = selectedQuestion.correctAnswer?.toString().trim();
      final explanationText = selectedQuestion.explanation?.toString().trim();
      final reviewMessage = StringBuffer()
        ..writeln('【題目送審】')
        ..writeln('題目：${questionText.isEmpty ? '未填寫' : questionText}')
        ..writeln('答案：${(answerText == null || answerText.isEmpty) ? '未填寫' : answerText}')
        ..writeln('解釋：${(explanationText == null || explanationText.isEmpty) ? '未填寫' : explanationText}');

      await _supabaseService.sendTeacherStudentMessage(
        studentId: user.id,
        senderId: user.id,
        senderRole: user.role,
        content: reviewMessage.toString(),
      );

      if (!mounted) return;
      setState(() {
        _messages.add({
          'student_id': user.id,
          'sender_id': user.id,
          'sender_role': user.role,
          'content': reviewMessage.toString(),
          'is_hand_raise': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      });
      _scrollToBottom(force: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已送出題目給老師審閱')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getSafeErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _initializeRealtimeSubscription({
    required String currentUserId,
    required bool isTeacher,
  }) {
    _disposeRealtimeSubscription();

    _realtimeChannel = _client.channel(
      'teacher-student-chat-$currentUserId-${DateTime.now().millisecondsSinceEpoch}',
    );

    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'teacher_student_messages',
          callback: (payload) => _onRealtimeMessageInserted(
            payload: payload,
            currentUserId: currentUserId,
            isTeacher: isTeacher,
          ),
        )
        .subscribe();
  }

  Future<void> _onRealtimeMessageInserted({
    required PostgresChangePayload payload,
    required String currentUserId,
    required bool isTeacher,
  }) async {
    if (!mounted) return;
    final newRecord = payload.newRecord;
    final incomingStudentId = newRecord['student_id']?.toString();
    if (incomingStudentId == null || incomingStudentId.isEmpty) return;
    final incomingSenderId = newRecord['sender_id']?.toString();
    final incomingContent = (newRecord['content']?.toString() ?? '').trim();
    final incomingSenderRole = newRecord['sender_role']?.toString() ?? '';

    // 學生只接收自己的聊天室更新
    if (!isTeacher && incomingStudentId != currentUserId) {
      return;
    }

    final isFromOtherSide = incomingSenderId != null && incomingSenderId != currentUserId;
    if (isFromOtherSide) {
      final contentPreview = incomingContent.isEmpty
          ? '您有一則新訊息'
          : (incomingContent.length > 30
              ? '${incomingContent.substring(0, 30)}...'
              : incomingContent);
      final title = isTeacher
          ? '學生新訊息'
          : (incomingSenderRole == 'teacher' ? '老師回覆了您' : '新訊息');
      _showInAppNotification(title: title, message: contentPreview);
    }

    if (isTeacher) {
      await _loadConversationSummaries();
      _applySearch(_searchController.text);
    }

    if (_selectedStudentId == incomingStudentId) {
      await _loadMessages(silent: true);
      _markCurrentChatAsRead();
    }
  }

  void _showInAppNotification({
    required String title,
    required String message,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$title：$message'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _disposeRealtimeSubscription() {
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) {
      _client.removeChannel(channel);
    }
  }

  void _startPollingFallback({required bool isTeacher}) {
    _stopPollingFallback();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _isSilentRefreshing) return;
      _isSilentRefreshing = true;
      try {
        if (isTeacher && _selectedStudentId == null) {
          await _loadConversationSummaries();
          _applySearch(_searchController.text);
        } else {
          await _loadMessages(silent: true);
          if (isTeacher) {
            await _loadConversationSummaries();
            _applySearch(_searchController.text);
          }
        }
      } catch (_) {
      } finally {
        _isSilentRefreshing = false;
      }
    });
  }

  void _stopPollingFallback() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  DateTime? _parseServerTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  DateTime? _toTaipeiTime(DateTime? time) {
    if (time == null) return null;
    return time.toUtc().add(const Duration(hours: 8));
  }

  String _formatTaipeiTime(String? raw, {bool short = false}) {
    final taipei = _toTaipeiTime(_parseServerTime(raw));
    if (taipei == null) return '';
    final hour = taipei.hour.toString().padLeft(2, '0');
    final minute = taipei.minute.toString().padLeft(2, '0');
    if (short) return '$hour:$minute';
    final month = taipei.month.toString().padLeft(2, '0');
    final day = taipei.day.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  String _formatTaipeiDateLabel(DateTime day) {
    final now = _toTaipeiTime(DateTime.now().toUtc());
    if (now != null) {
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      if (day == today) return '今天';
      if (day == yesterday) return '昨天';
    }
    final month = day.month.toString().padLeft(2, '0');
    final dayStr = day.day.toString().padLeft(2, '0');
    return '${day.year}/$month/$dayStr';
  }

  List<_TeacherStudentChatListItem> _buildMessageListItems() {
    final items = <_TeacherStudentChatListItem>[];
    DateTime? lastDay;
    for (final msg in _messages) {
      final taipei = _toTaipeiTime(_parseServerTime(msg['created_at']?.toString()));
      if (taipei != null) {
        final day = DateTime(taipei.year, taipei.month, taipei.day);
        if (lastDay == null || day != lastDay) {
          items.add(_TeacherStudentChatListItem.date(_formatTaipeiDateLabel(day)));
          lastDay = day;
        }
      }
      items.add(_TeacherStudentChatListItem.message(msg));
    }
    return items;
  }

  Widget _buildDateDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: TeacherStudentChatTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  void _markCurrentChatAsRead() {
    final studentId = _selectedStudentId;
    if (studentId == null) return;
    DateTime? latest;
    for (final msg in _messages) {
      final parsed = _parseServerTime(msg['created_at']?.toString());
      if (parsed == null) continue;
      if (latest == null || parsed.isAfter(latest)) {
        latest = parsed;
      }
    }
    _lastReadAtByStudent[studentId] = latest ?? DateTime.now().toUtc();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final teacherId = authProvider.currentUser?.id;
    if (teacherId != null) {
      _persistReadStatusForStudent(
        teacherId: teacherId,
        studentId: studentId,
        readAt: _lastReadAtByStudent[studentId]!,
      );
    }
  }

  bool _hasUnreadForTeacher(Map<String, dynamic> item) {
    final studentId = item['student_id'] as String?;
    if (studentId == null || studentId.isEmpty) return false;
    final latestSenderRole = item['latest_sender_role'] as String? ?? '';
    if (latestSenderRole != 'student') return false;
    final latestTime = _parseServerTime(item['latest_created_at'] as String?);
    if (latestTime == null) return false;
    final readAt = _lastReadAtByStudent[studentId];
    if (readAt == null) return true;
    return latestTime.isAfter(readAt);
  }

  Future<void> _loadPersistedReadStatus(String teacherId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_teacherReadAtStoragePrefix$teacherId';
    final stored = prefs.getStringList(key) ?? [];
    _lastReadAtByStudent.clear();
    for (final entry in stored) {
      final parts = entry.split('|');
      if (parts.length != 2) continue;
      final studentId = parts[0];
      final readAt = DateTime.tryParse(parts[1]);
      if (studentId.isEmpty || readAt == null) continue;
      _lastReadAtByStudent[studentId] = readAt;
    }
  }

  Future<void> _persistReadStatusForStudent({
    required String teacherId,
    required String studentId,
    required DateTime readAt,
  }) async {
    _lastReadAtByStudent[studentId] = readAt;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_teacherReadAtStoragePrefix$teacherId';
    final payload = _lastReadAtByStudent.entries
        .map((e) => '${e.key}|${e.value.toIso8601String()}')
        .toList();
    await prefs.setStringList(key, payload);
  }

  void _scrollToBottom({bool force = false}) {
    if (!force && !_isNearBottom()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final isTeacher = user?.role == 'teacher';
    final inConversation = !isTeacher || _selectedStudentId != null;
    Map<String, dynamic>? selectedSummary;
    if (isTeacher && _selectedStudentId != null) {
      for (final item in _conversationSummaries) {
        if (item['student_id'] == _selectedStudentId) {
          selectedSummary = item;
          break;
        }
      }
    }
    final selectedStudentName = selectedSummary?['student_name']?.toString() ?? '';
    final selectedClassName = selectedSummary?['class_name']?.toString() ?? '';

    final viewBottom = MediaQuery.viewInsetsOf(context).bottom;
    final messageListBottomPadding =
        12.0 + (inConversation ? _messageInputBarExtent + viewBottom : 0.0);
    final messageListItems =
        inConversation ? _buildMessageListItems() : const <_TeacherStudentChatListItem>[];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: TeacherStudentChatTheme.palette.gradientEnd,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.72),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: TeacherStudentChatTheme.textPrimary,
        leading: isTeacher && inConversation
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _backToConversationList,
              )
            : null,
        title: Text(
          isTeacher
              ? (inConversation
                  ? (selectedStudentName.isEmpty
                      ? '聊天室'
                      : '聊天室 - $selectedStudentName${selectedClassName.isNotEmpty ? '（$selectedClassName）' : ''}')
                  : '學生聊天室列表')
              : '向老師提問',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ChatPastelBackground(palette: ChatPastelPalette.teacherStudent),
          Column(
            children: [
              if (isTeacher && !inConversation)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _applySearch,
                    style: const TextStyle(color: TeacherStudentChatTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: '搜尋學生姓名或訊息',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: Icon(
                        Icons.search,
                        color: TeacherStudentChatTheme.accent,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(TeacherStudentChatTheme.radiusPill),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(TeacherStudentChatTheme.radiusPill),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(TeacherStudentChatTheme.radiusPill),
                        borderSide: BorderSide(
                          color: TeacherStudentChatTheme.accent.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              Expanded(
                child: isTeacher && !inConversation
                    ? _buildConversationList()
                    : (_isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: TeacherStudentChatTheme.accent,
                            ),
                          )
                        : _messages.isEmpty
                            ? const Center(
                                child: Text(
                                  '目前沒有訊息',
                                  style: TextStyle(
                                    color: TeacherStudentChatTheme.textSecondary,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  messageListBottomPadding,
                                ),
                                itemCount: messageListItems.length,
                                itemBuilder: (context, index) {
                                  final item = messageListItems[index];
                                  if (item.isDateDivider) {
                                    return _buildDateDivider(item.dateLabel!);
                                  }
                                  final msg = item.message!;
                                  final mine = msg['sender_id'] == user?.id;
                                  final role = msg['sender_role'] as String? ?? '';
                                  final content = msg['content'] as String? ?? '';
                                  final isHandRaise = msg['is_hand_raise'] == true;
                                  final timeText = _formatTaipeiTime(
                                    msg['created_at']?.toString(),
                                    short: true,
                                  );
                                  return LayoutBuilder(
                                    builder: (context, constraints) {
                                      final maxBubbleWidth =
                                          constraints.maxWidth * 0.72;
                                      final estimatedWidth = (content.length *
                                                  16.0 +
                                              72.0)
                                          .clamp(92.0, maxBubbleWidth);
                                      return Align(
                                        alignment: mine
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: TeacherStudentChatTheme.messageBubble(
                                          isUser: mine,
                                          width: estimatedWidth,
                                          border: isHandRaise
                                              ? Border.all(
                                                  color: Colors.orange.shade400,
                                                  width: 1.2,
                                                )
                                              : null,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isHandRaise
                                                    ? '舉手提問 - $role'
                                                    : role,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: mine
                                                      ? TeacherStudentChatTheme.accent
                                                      : TeacherStudentChatTheme
                                                          .textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                content,
                                                softWrap: true,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  height: 1.45,
                                                  color: TeacherStudentChatTheme
                                                      .textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Align(
                                                alignment: Alignment.centerRight,
                                                child: Text(
                                                  timeText,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: TeacherStudentChatTheme
                                                        .textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              )),
              ),
            ],
          ),
          if (inConversation)
            Positioned(
              left: 0,
              right: 0,
              bottom: viewBottom,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isTeacher) ...[
                      ChatUiTheme.circleIconButton(
                        icon: Icons.assignment_outlined,
                        accent: TeacherStudentChatTheme.accent,
                        tooltip: '選擇題目送審',
                        onPressed:
                            _isSending ? null : _sendQuestionForReview,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(
                          color: TeacherStudentChatTheme.textPrimary,
                        ),
                        decoration: ChatUiTheme.pillInputDecoration(
                          hintText: '輸入訊息',
                          accent: TeacherStudentChatTheme.accent,
                        ),
                        minLines: 1,
                        maxLines: 3,
                        scrollPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isTeacher)
                      ChatUiTheme.circleIconButton(
                        icon: Icons.pan_tool_alt_outlined,
                        accent: TeacherStudentChatTheme.accent,
                        tooltip: '舉手提問',
                        onPressed: _isSending
                            ? null
                            : () => _sendMessage(isHandRaise: true),
                      ),
                    if (!isTeacher) const SizedBox(width: 8),
                    ChatUiTheme.circleIconButton(
                      icon: Icons.arrow_upward_rounded,
                      accent: TeacherStudentChatTheme.accent,
                      tooltip: '送出',
                      onPressed: _isSending
                          ? null
                          : () => _sendMessage(isHandRaise: false),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: TeacherStudentChatTheme.accent),
      );
    }
    if (_filteredSummaries.isEmpty) {
      return const Center(
        child: Text(
          '找不到符合條件的學生',
          style: TextStyle(color: TeacherStudentChatTheme.textSecondary),
        ),
      );
    }
    final activeHandRaises = _filteredSummaries.where((item) {
      final latestSenderRole = item['latest_sender_role'] as String? ?? '';
      final isHandRaise = item['is_hand_raise'] == true;
      return latestSenderRole == 'student' && isHandRaise;
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _filteredSummaries.length + (activeHandRaises.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (activeHandRaises.isNotEmpty && index == 0) {
          final names = activeHandRaises
              .map((e) => (e['student_name'] as String?) ?? '未命名學生')
              .toList();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notification_important, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '舉手提醒：${names.join('、')}',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final item = _filteredSummaries[index - (activeHandRaises.isNotEmpty ? 1 : 0)];
        final name = item['student_name'] as String? ?? '未命名學生';
        final className = item['class_name'] as String? ?? '未加入班級';
        final preview = item['latest_content'] as String? ?? '';
        final createdAt = DateTime.tryParse((item['latest_created_at'] ?? '').toString());
        final hasHandRaise = item['is_hand_raise'] == true;
        final hasUnread = _hasUnreadForTeacher(item);
        final subtitle = preview.isEmpty ? '班級：$className' : '班級：$className  ｜  $preview';
        final timeText = createdAt == null ? '' : _formatTaipeiTime(item['latest_created_at']?.toString());

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: ChatUiTheme.listCardDecoration(),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onTap: () => _openStudentChat(item['student_id'] as String),
            leading: CircleAvatar(
              backgroundColor: hasHandRaise
                  ? Colors.orange.shade100
                  : TeacherStudentChatTheme.accentSoft.withValues(alpha: 0.45),
              child: Icon(
                hasHandRaise ? Icons.pan_tool_alt_outlined : Icons.person_outline,
                color: hasHandRaise
                    ? Colors.orange.shade700
                    : TeacherStudentChatTheme.accent,
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: TeacherStudentChatTheme.textPrimary,
              ),
            ),
            subtitle: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: TeacherStudentChatTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: TeacherStudentChatTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                if (hasUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '未讀',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TeacherStudentChatListItem {
  const _TeacherStudentChatListItem.date(this.dateLabel) : message = null;

  const _TeacherStudentChatListItem.message(this.message) : dateLabel = null;

  final String? dateLabel;
  final Map<String, dynamic>? message;

  bool get isDateDivider => dateLabel != null;
}
