import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import '../../providers/grammar_topic_provider.dart';
import 'tabs/grammar_key_points_tab.dart';
import 'tabs/reminders_tab.dart';
import 'tabs/question_generation_tab.dart';
import 'tabs/profile_tab.dart';

class StudentMainScreen extends StatefulWidget {
  const StudentMainScreen({super.key});

  @override
  State<StudentMainScreen> createState() => _StudentMainScreenState();
}

class _StudentMainScreenState extends State<StudentMainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
      await grammarTopicProvider.loadTopics();
      // 初始化 Realtime 訂閱以接收即時通知
      await grammarTopicProvider.initializeRealtimeSubscription();
    });
  }

  @override
  void dispose() {
    // 取消 Realtime 訂閱
    Provider.of<GrammarTopicProvider>(context, listen: false).disposeRealtimeSubscription();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
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
