import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import 'tabs/classes_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/statistics_tab.dart';
import '../student/tabs/profile_tab.dart';

class TeacherMainScreen extends StatefulWidget {
  const TeacherMainScreen({super.key});

  @override
  State<TeacherMainScreen> createState() => _TeacherMainScreenState();
}

class _TeacherMainScreenState extends State<TeacherMainScreen> {
  int _currentIndex = 0;
  final SupabaseClient _client = Supabase.instance.client;
  final SupabaseService _supabaseService = SupabaseService();
  RealtimeChannel? _messageNotifyChannel;
  String? _boundNotifyUserId;
  Timer? _notifyPollingTimer;
  String? _lastNotifiedMessageId;
  bool _notifyWarmupDone = false;
  final Map<String, String> _studentNameCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindMessageNotificationsIfNeeded());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindMessageNotificationsIfNeeded();
  }

  @override
  void dispose() {
    final channel = _messageNotifyChannel;
    _messageNotifyChannel = null;
    if (channel != null) {
      _client.removeChannel(channel);
    }
    _notifyPollingTimer?.cancel();
    _notifyPollingTimer = null;
    super.dispose();
  }

  void _bindMessageNotificationsIfNeeded() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    if (currentUserId == null) return;
    if (_boundNotifyUserId == currentUserId && _messageNotifyChannel != null) return;

    final oldChannel = _messageNotifyChannel;
    _messageNotifyChannel = null;
    if (oldChannel != null) {
      _client.removeChannel(oldChannel);
    }

    final channelName = 'teacher-in-app-notify-$currentUserId-${DateTime.now().millisecondsSinceEpoch}';
    final channel = _client.channel(channelName);
    _messageNotifyChannel = channel;
    _boundNotifyUserId = currentUserId;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'teacher_student_messages',
          callback: (payload) async {
            if (!mounted) return;
            final senderId = payload.newRecord['sender_id']?.toString();
            final senderRole = payload.newRecord['sender_role']?.toString() ?? '';
            final studentId = payload.newRecord['student_id']?.toString();
            final content = (payload.newRecord['content']?.toString() ?? '').trim();
            if (senderId == currentUserId || senderRole != 'student') return;
            final studentName = await _getStudentName(studentId);
            final preview = content.isEmpty
                ? '收到一則新訊息'
                : (content.length > 30 ? '${content.substring(0, 30)}...' : content);
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text('學生 $studentName：$preview'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
          },
        )
        .subscribe();
    _startNotifyPolling(currentUserId);
  }

  void _startNotifyPolling(String currentUserId) {
    _notifyPollingTimer?.cancel();
    _notifyPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      final latest = await _supabaseService.getLatestIncomingTeacherStudentMessage(
        currentUserId: currentUserId,
        isTeacher: true,
      );
      if (latest == null) return;
      final messageId = latest['id']?.toString();
      if (messageId == null || messageId.isEmpty) return;

      if (!_notifyWarmupDone) {
        _lastNotifiedMessageId = messageId;
        _notifyWarmupDone = true;
        return;
      }
      if (_lastNotifiedMessageId == messageId) return;
      _lastNotifiedMessageId = messageId;

      final content = (latest['content']?.toString() ?? '').trim();
      final studentId = latest['student_id']?.toString();
      final studentName = await _getStudentName(studentId);
      final preview = content.isEmpty
          ? '收到一則新訊息'
          : (content.length > 30 ? '${content.substring(0, 30)}...' : content);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('學生 $studentName：$preview'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    });
  }

  Future<String> _getStudentName(String? studentId) async {
    if (studentId == null || studentId.isEmpty) return '未知學生';
    final cached = _studentNameCache[studentId];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final students = await _supabaseService.getAllStudents();
      for (final student in students) {
        final id = student['id']?.toString();
        final name = student['name']?.toString();
        if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
          _studentNameCache[id] = name;
        }
      }
      return _studentNameCache[studentId] ?? '未知學生';
    } catch (_) {
      return '未知學生';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final shouldInsetBottomTabBar = isAndroid ? true : !PlatformVersion.shouldUseNativeGlass;
    final bottomBarExtraPadding = isAndroid ? 6.0 : 0.0;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: !shouldInsetBottomTabBar,
        child: Stack(
          fit: StackFit.expand,
          children: [
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                ClassesTab(),
                DashboardTab(),
                StatisticsTab(),
                ProfileTab(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              bottom: shouldInsetBottomTabBar,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomBarExtraPadding),
                child: CNTabBar(
                  backgroundColor: Colors.transparent,
                  items: const [
                    CNTabBarItem(
                      label: '班級',
                      icon: CNSymbol('person.3'),
                      activeIcon: CNSymbol('person.3.fill'),
                    ),
                    CNTabBarItem(
                      label: '儀錶板',
                      icon: CNSymbol('square.grid.2x2'),
                      activeIcon: CNSymbol('square.grid.2x2.fill'),
                    ),
                    CNTabBarItem(
                      label: '數據',
                      icon: CNSymbol('chart.bar'),
                      activeIcon: CNSymbol('chart.bar.fill'),
                    ),
                    CNTabBarItem(
                      label: '個人',
                      icon: CNSymbol('person'),
                      activeIcon: CNSymbol('person.fill'),
                    ),
                  ],
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    if (_currentIndex != index) {
                      setState(() => _currentIndex = index);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
