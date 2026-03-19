import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
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
              bottom: false,
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
        ],
        ),
      ),
    );
  }
}
