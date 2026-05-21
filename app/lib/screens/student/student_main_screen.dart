import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../providers/grammar_topic_provider.dart';
import '../../providers/class_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ai_chat_settings_provider.dart';
import '../../services/supabase_service.dart';
import 'tabs/grammar_key_points_tab.dart';
import 'tabs/reminders_tab.dart';
import 'tabs/question_generation_tab.dart';
import 'tabs/profile_tab.dart';
import 'join_class_screen.dart';
import '../../widgets/adaptive_app_dialog.dart';
import '../../widgets/student_feedback_prompt_dialog.dart';
import '../../services/student_feedback_prompt_service.dart';
import '../../config/app_config.dart';
import '../../widgets/sgq_main_loading_overlay.dart';
import '../../widgets/sgq_floating_glass_tab_bar.dart';
import 'dart:io' show Platform;

class StudentMainScreen extends StatefulWidget {
  const StudentMainScreen({super.key});

  @override
  State<StudentMainScreen> createState() => _StudentMainScreenState();
}

class _StudentMainScreenState extends State<StudentMainScreen> {
  int _currentIndex = 0;
  bool _isCheckingClass = true;
  final SupabaseClient _client = Supabase.instance.client;
  final SupabaseService _supabaseService = SupabaseService();
  RealtimeChannel? _messageNotifyChannel;
  String? _boundNotifyUserId;
  Timer? _notifyPollingTimer;
  String? _lastNotifiedMessageId;
  bool _notifyWarmupDone = false;
  bool _isNotifyDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkClassAndLoadTopics();
      _bindMessageNotificationsIfNeeded();
    });
  }

  /// 原生 CNTabBar 初次建立時常無法渲染未選中分頁的標題；
  /// 在載入遮罩下依序切換分頁，觸發原生 layout 後再還原。
  Future<void> _warmUpTabBarLabels() async {
    const tabCount = 4;
    for (var i = 1; i < tabCount; i++) {
      if (!mounted) return;
      setState(() => _currentIndex = i);
      await Future.delayed(const Duration(milliseconds: 45));
    }
    if (!mounted) return;
    setState(() => _currentIndex = 0);
    await Future.delayed(const Duration(milliseconds: 120));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindMessageNotificationsIfNeeded();
  }

  Future<void> _checkClassAndLoadTopics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final classProvider = Provider.of<ClassProvider>(context, listen: false);
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
    final aiSettingsProvider = Provider.of<AiChatSettingsProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      final currentUser = authProvider.currentUser!;
      // 載入學生所屬的班級
      await classProvider.loadStudentClass(currentUser.id);
      
      // 根據班級載入課程
      if (classProvider.studentClass != null) {
        await grammarTopicProvider.loadTopics(classId: classProvider.studentClass!.id);
      } else {
        await grammarTopicProvider.loadTopics();
      }

      // 初始化班級 AI 小幫手設定並啟用即時監聽
      await aiSettingsProvider.refreshForStudent(
        studentId: currentUser.id,
        classId: classProvider.studentClass?.id ?? currentUser.classId,
      );
      
      // 初始化 Realtime 訂閱以接收即時通知
      await grammarTopicProvider.initializeRealtimeSubscription();
    }

    if (mounted) {
      if (classProvider.studentClass != null && !Platform.isAndroid) {
        await _warmUpTabBarLabels();
      }
      setState(() {
        _isCheckingClass = false;
      });
      await _maybeShowStudentFeedbackPrompt();
    }
  }

  Future<void> _maybeShowStudentFeedbackPrompt() async {
    if (!mounted) return;
    final shouldShow = await StudentFeedbackPromptService.shouldShowPrompt();
    if (!shouldShow || !mounted) return;

    final formUrl = AppConfig.studentFeedbackFormUrl.trim();
    if (formUrl.isEmpty) return;

    await showStudentFeedbackPromptDialog(
      context: context,
      formUrl: formUrl,
    );
    await StudentFeedbackPromptService.markPromptHandledForCurrentVersion();
  }

  @override
  void dispose() {
    // 取消 Realtime 訂閱
    Provider.of<GrammarTopicProvider>(context, listen: false).disposeRealtimeSubscription();
    Provider.of<AiChatSettingsProvider>(context, listen: false).disposeRealtimeSubscription();
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

    final channelName = 'student-in-app-notify-$currentUserId-${DateTime.now().millisecondsSinceEpoch}';
    final channel = _client.channel(channelName);
    _messageNotifyChannel = channel;
    _boundNotifyUserId = currentUserId;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'teacher_student_messages',
          callback: (payload) {
            if (!mounted) return;
            final senderId = payload.newRecord['sender_id']?.toString();
            final senderRole = payload.newRecord['sender_role']?.toString() ?? '';
            final studentId = payload.newRecord['student_id']?.toString();
            final content = (payload.newRecord['content']?.toString() ?? '').trim();
            if (studentId != currentUserId) return;
            if (senderId == currentUserId || senderRole != 'teacher') return;
            final preview = content.isEmpty
                ? '收到一則新訊息'
                : (content.length > 30 ? '${content.substring(0, 30)}...' : content);
            _showMessageNotifyDialog(
              title: '老師回覆了您',
              message: '老師回覆：$preview',
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
        isTeacher: false,
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
      final preview = content.isEmpty
          ? '收到一則新訊息'
          : (content.length > 30 ? '${content.substring(0, 30)}...' : content);
      _showMessageNotifyDialog(
        title: '老師回覆了您',
        message: '老師回覆：$preview',
      );
    });
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

  void _navigateToJoinClass() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const JoinClassScreen()),
    );
    
    if (result == true && mounted) {
      // 重新載入班級和課程
      setState(() {
        _isCheckingClass = true;
      });
      await _checkClassAndLoadTopics();
    }
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final confirmed = await AdaptiveAppDialog.showConfirm(
      context: context,
      title: '確認登出',
      message: '確定要登出嗎？',
      confirmLabel: '登出',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signOut();
  }

  /// 非 iOS 26：TabBar 背景延伸至螢幕底，Home Indicator 區用內距留白，避免 SafeArea 外側空隙。
  Widget _buildStudentBottomTabBar({
    required bool isAndroid,
    required bool shouldInsetBottomTabBar,
    required double bottomBarExtraPadding,
    required bool extendBarThroughHomeIndicator,
  }) {
    if (isAndroid) {
      return SafeArea(
        top: false,
        bottom: true,
        child: SgqFloatingGlassTabBar(
          currentIndex: _currentIndex,
          bottomMargin: bottomBarExtraPadding,
          items: const [
            SgqFloatingGlassTabItem(
              label: '文法重點',
              icon: Icons.flag_outlined,
              activeIcon: Icons.flag,
            ),
            SgqFloatingGlassTabItem(
              label: '出題重點提醒',
              icon: Icons.format_list_bulleted_outlined,
              activeIcon: Icons.format_list_bulleted,
            ),
            SgqFloatingGlassTabItem(
              label: '出題區',
              icon: Icons.check_circle_outline,
              activeIcon: Icons.check_circle,
            ),
            SgqFloatingGlassTabItem(
              label: '個人',
              icon: Icons.person_outline,
              activeIcon: Icons.person,
            ),
          ],
          onTap: (index) {
            if (_currentIndex != index) {
              setState(() => _currentIndex = index);
            }
          },
        ),
      );
    }

    final tabBar = CNTabBar(
      key: const ValueKey('student-main-tab-bar'),
      backgroundColor: Colors.transparent,
      items: const [
        CNTabBarItem(
          label: '文法重點',
          icon: CNSymbol('flag'),
          activeIcon: CNSymbol('flag.fill'),
        ),
        CNTabBarItem(
          label: '出題重點提醒',
          icon: CNSymbol('list.bullet'),
          activeIcon: CNSymbol('list.bullet'),
        ),
        CNTabBarItem(
          label: '出題區',
          icon: CNSymbol('checkmark.circle'),
          activeIcon: CNSymbol('checkmark.circle.fill'),
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

  Widget _buildMainTabScaffold({
    required bool showLoadingOverlay,
  }) {
    final platform = Theme.of(context).platform;
    final isAndroid = platform == TargetPlatform.android;
    final isIOS = platform == TargetPlatform.iOS;
    final shouldInsetBottomTabBar = isAndroid ? true : !PlatformVersion.shouldUseNativeGlass;
    final extendBarThroughHomeIndicator = isIOS && shouldInsetBottomTabBar;
    final bottomBarExtraPadding = isAndroid ? 12.0 : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
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
                  GrammarKeyPointsTab(),
                  RemindersTab(),
                  QuestionGenerationTab(),
                  ProfileTab(),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildStudentBottomTabBar(
                isAndroid: isAndroid,
                shouldInsetBottomTabBar: shouldInsetBottomTabBar,
                bottomBarExtraPadding: bottomBarExtraPadding,
                extendBarThroughHomeIndicator: extendBarThroughHomeIndicator,
              ),
            ),
            if (showLoadingOverlay)
              const SgqMainLoadingOverlay(message: '載入中...'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classProvider = Provider.of<ClassProvider>(context, listen: false);

    // 載入班級資料時以全螢幕遮罩覆蓋（含 tab bar），遮罩下預熱分頁標題
    if (_isCheckingClass) {
      return _buildMainTabScaffold(showLoadingOverlay: true);
    }

    // 如果學生尚未加入班級，顯示提示畫面
    if (classProvider.studentClass == null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // 頂部區域 - 顯示帳號資訊和登出按鈕
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authProvider.currentUser?.name ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            authProvider.currentUser?.email ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showLogoutConfirmation(context),
                      icon: Icon(Icons.logout, color: Colors.red.shade600, size: 20),
                      label: Text(
                        '登出',
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 主要內容
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.class_outlined,
                          size: 100,
                          color: Colors.indigo.shade300,
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          '尚未加入班級',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '請輸入老師提供的班級代碼\n加入班級後即可使用所有功能',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _navigateToJoinClass,
                          icon: const Icon(Icons.add),
                          label: const Text('加入班級'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildMainTabScaffold(showLoadingOverlay: false);
  }
}
