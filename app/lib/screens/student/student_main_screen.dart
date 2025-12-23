import 'package:flutter/material.dart';
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
      Provider.of<GrammarTopicProvider>(context, listen: false).loadTopics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          GrammarKeyPointsTab(),
          RemindersTab(),
          QuestionGenerationTab(),
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.green.shade600,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.flag),
              label: '文法重點',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list),
              label: '出題重點提醒',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle),
              label: '出題區',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: '個人',
            ),
          ],
        ),
      ),
    );
  }
}
