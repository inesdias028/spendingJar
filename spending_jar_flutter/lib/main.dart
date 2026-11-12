import 'package:flutter/material.dart';

import 'jar_page.dart';
import 'models.dart';
import 'stats_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  await store.load();
  runApp(SpendingJarApp(store: store));
}

class AppColors {
  static const background = Color(0xFFFAF7F2);
  static const card = Colors.white;
  static const green = Color(0xFF4CAF7A);
  static const darkGreen = Color(0xFF2F7D55);
  static const orange = Color(0xFFF2A541);
  static const red = Color(0xFFE05A5A);
  static const blue = Color(0xFF3A6EA5);
  static const track = Color(0xFFEEE7DC);
  static const text = Color(0xFF222222);
  static const muted = Color(0xFF888888);
}

class SpendingJarApp extends StatelessWidget {
  const SpendingJarApp({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spending Jar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
          surface: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: HomeShell(store: store),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final Store store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          JarPage(store: widget.store),
          StatsPage(store: widget.store),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE6F2EA),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings, color: AppColors.darkGreen),
            label: 'Jar',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppColors.darkGreen),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}
