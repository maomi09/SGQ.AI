import 'package:flutter/material.dart';
import 'tabs/courses_tab.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          CoursesTab(),
          DashboardTab(),
          StatisticsTab(),
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
              icon: Icon(Icons.book),
              label: '課程',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: '儀錶板',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: '數據',
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
