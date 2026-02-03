import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final grammarTopicProvider = Provider.of<GrammarTopicProvider>(context, listen: false);
      grammarTopicProvider.loadTopics();
      // 初始化 Realtime 訂閱以接收即時通知
      grammarTopicProvider.initializeRealtimeSubscription();
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
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: const [
              GrammarKeyPointsTab(),
              RemindersTab(),
              QuestionGenerationTab(),
              ProfileTab(),
            ],
          ),
          // 浮動導航欄
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final itemWidth = constraints.maxWidth / 4;
                          return Stack(
                            children: [
                              // 半透明方塊指示器
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                left: _currentIndex * itemWidth,
                                top: 0,
                                bottom: 0,
                                width: itemWidth,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              // 導航項目
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildNavItem(
                                    key: const ValueKey(0),
                                    icon: Icons.flag,
                                    label: '文法重點',
                                    index: 0,
                                  ),
                                  _buildNavItem(
                                    key: const ValueKey(1),
                                    icon: Icons.list,
                                    label: '出題重點提醒',
                                    index: 1,
                                  ),
                                  _buildNavItem(
                                    key: const ValueKey(2),
                                    icon: Icons.check_circle,
                                    label: '出題區',
                                    index: 2,
                                  ),
                                  _buildNavItem(
                                    key: const ValueKey(3),
                                    icon: Icons.person,
                                    label: '個人',
                                    index: 3,
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required Key key,
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      key: key,
      child: InkWell(
        onTap: () {
          if (_currentIndex != index) {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: Icon(
                  icon,
                  color: isSelected ? Colors.green.shade600 : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.green.shade600 : Colors.grey,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
