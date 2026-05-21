import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../services/supabase_service.dart';
import 'tabs/classes_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/statistics_tab.dart';
import 'tabs/questions_tab.dart';
import '../student/tabs/profile_tab.dart';
import '../../widgets/adaptive_app_dialog.dart';
import '../../widgets/sgq_main_loading_overlay.dart';

class TeacherMainScreen extends StatefulWidget {
  const TeacherMainScreen({super.key});

  @override
  State<TeacherMainScreen> createState() => _TeacherMainScreenState();
}

class _TeacherMainScreenState extends State<TeacherMainScreen> {
  /// 班級分頁（與 [IndexedStack] 順序一致，啟動／登入後固定停留此頁）
  static const int _classesTabIndex = 0;

  int _currentIndex = _classesTabIndex;
  bool _isTabBarWarmingUp = true;
  final SupabaseClient _client = Supabase.instance.client;
  final SupabaseService _supabaseService = SupabaseService();
  RealtimeChannel? _messageNotifyChannel;
  String? _boundNotifyUserId;
  Timer? _notifyPollingTimer;
  String? _lastNotifiedMessageId;
  bool _notifyWarmupDone = false;
  final Map<String, String> _studentNameCache = {};
  bool _isNotifyDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user != null && user.role == 'teacher') {
        await Provider.of<ClassProvider>(context, listen: false)
            .loadTeacherClasses(user.id);
      }
      await _warmUpTabBarLabels();
      if (mounted) {
        setState(() => _isTabBarWarmingUp = false);
      }
      _bindMessageNotificationsIfNeeded();
    });
  }

  /// 原生 CNTabBar 初次建立時常無法正確渲染未選中分頁標題，造成底部列抽動。
  Future<void> _warmUpTabBarLabels() async {
    const tabCount = 5;
    for (var i = 1; i < tabCount; i++) {
      if (!mounted) return;
      setState(() => _currentIndex = i);
      await Future.delayed(const Duration(milliseconds: 45));
    }
    if (!mounted) return;
    setState(() => _currentIndex = _classesTabIndex);
    await Future.delayed(const Duration(milliseconds: 120));
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
            _showMessageNotifyDialog(
              title: '學生新訊息',
              message: '學生 $studentName：$preview',
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
      _showMessageNotifyDialog(
        title: '學生新訊息',
        message: '學生 $studentName：$preview',
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

  Future<void> _showMessageNotifyDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted || _isNotifyDialogShowing) return;
    _isNotifyDialogShowing = true;
    await AdaptiveAppDialog.showNotify(
      context: context,
      title: title,
      message: message,
    );
    _isNotifyDialogShowing = false;
  }

  /// 非 iOS 26：TabBar 背景延伸至螢幕底，Home Indicator 區用內距留白，避免 SafeArea 外側空隙。
  Widget _buildTeacherBottomTabBar({
    required bool shouldInsetBottomTabBar,
    required double bottomBarExtraPadding,
    required bool extendBarThroughHomeIndicator,
  }) {
    final tabBar = CNTabBar(
      key: const ValueKey('teacher-main-tab-bar'),
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
          label: '題目',
          icon: CNSymbol('doc.text'),
          activeIcon: CNSymbol('doc.text.fill'),
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
    );

    if (extendBarThroughHomeIndicator) {
      final bottomInset = MediaQuery.paddingOf(context).bottom;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          border: Border(
            top: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: bottomInset + bottomBarExtraPadding,
          ),
          child: tabBar,
        ),
      );
    }

    return SafeArea(
      top: false,
      bottom: shouldInsetBottomTabBar,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomBarExtraPadding),
        child: tabBar,
      ),
    );
  }

  Widget _buildMainTabScaffold({required bool showLoadingOverlay}) {
    final platform = Theme.of(context).platform;
    final isAndroid = platform == TargetPlatform.android;
    final isIOS = platform == TargetPlatform.iOS;
    final shouldInsetBottomTabBar = isAndroid ? true : !PlatformVersion.shouldUseNativeGlass;
    final extendBarThroughHomeIndicator = isIOS && shouldInsetBottomTabBar;
    final bottomBarExtraPadding = isAndroid ? 6.0 : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: isIOS,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: DecoratedBox(
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
              ),
            ),
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: const [
                  ClassesTab(),
                  DashboardTab(),
                  QuestionsTab(),
                  StatisticsTab(),
                  ProfileTab(),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildTeacherBottomTabBar(
                shouldInsetBottomTabBar: shouldInsetBottomTabBar,
                bottomBarExtraPadding: bottomBarExtraPadding,
                extendBarThroughHomeIndicator: extendBarThroughHomeIndicator,
              ),
            ),
            if (showLoadingOverlay)
              const SgqMainLoadingOverlay(message: '準備中...'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildMainTabScaffold(showLoadingOverlay: _isTabBarWarmingUp);
  }
}
