import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import '../../providers/grammar_topic_provider.dart';
import '../../providers/class_provider.dart';
import '../../providers/auth_provider.dart';
import 'tabs/grammar_key_points_tab.dart';
import 'tabs/reminders_tab.dart';
import 'tabs/question_generation_tab.dart';
import 'tabs/profile_tab.dart';
import 'join_class_screen.dart';

class StudentMainScreen extends StatefulWidget {
  const StudentMainScreen({super.key});

  @override
  State<StudentMainScreen> createState() => _StudentMainScreenState();
}

class _StudentMainScreenState extends State<StudentMainScreen> {
  int _currentIndex = 0;
  bool _isCheckingClass = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkClassAndLoadTopics();
    });
  }

  Future<void> _checkClassAndLoadTopics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final classProvider = Provider.of<ClassProvider>(context, listen: false);
    final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      // 載入學生所屬的班級
      await classProvider.loadStudentClass(authProvider.currentUser!.id);
      
      // 根據班級載入課程
      if (classProvider.studentClass != null) {
        await grammarTopicProvider.loadTopics(classId: classProvider.studentClass!.id);
      } else {
        await grammarTopicProvider.loadTopics();
      }
      
      // 初始化 Realtime 訂閱以接收即時通知
      await grammarTopicProvider.initializeRealtimeSubscription();
    }

    if (mounted) {
      setState(() {
        _isCheckingClass = false;
      });
    }
  }

  @override
  void dispose() {
    // 取消 Realtime 訂閱
    Provider.of<GrammarTopicProvider>(context, listen: false).disposeRealtimeSubscription();
    super.dispose();
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

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('確認登出'),
        content: const Text('確定要登出嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.signOut();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('登出'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classProvider = Provider.of<ClassProvider>(context);
    
    // 如果正在檢查班級狀態，顯示載入指示器
    if (_isCheckingClass) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
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

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
          const Positioned.fill(
            child: ColoredBox(color: Colors.white),
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
            child: SafeArea(
              top: false,
              bottom: false,
              child: CNTabBar(
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
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
