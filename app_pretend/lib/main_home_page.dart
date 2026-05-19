import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/view/dashboard_page.dart';
import 'features/visualizer/view/visualizer_page.dart';
import 'features/controller/view/controller_page.dart';

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // 禁用滑动切换，避免冲突
        children: const [
          DashboardPage(),
          VisualizerPage(),
          ControllerPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryMain,
        unselectedItemColor: AppTheme.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: '数据'),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: '控制'),
        ],
      ),
    );
  }
}
