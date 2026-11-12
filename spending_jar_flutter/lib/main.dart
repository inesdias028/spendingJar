import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth_page.dart';
import 'firebase_options.dart';
import 'jar_page.dart';
import 'models.dart';
import 'stats_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  if (!DefaultFirebaseOptions.isConfigured) {
    startupError = 'Firebase is not set up yet. Fill in lib/firebase_options.dart with your project\'s settings.';
  } else {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      startupError = 'Could not connect to Firebase: $e';
    }
  }
  runApp(SpendingJarApp(startupError: startupError));
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
  const SpendingJarApp({super.key, this.startupError});
  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spending Jar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green, surface: AppColors.background),
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: startupError != null ? _Message(text: startupError!) : const AuthGate(),
    );
  }
}

/// Shows the login screen when signed out, and the app when signed in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const AuthPage();
        // A new key per user, so signing in as someone else starts a fresh store.
        return _SignedIn(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

class _SignedIn extends StatefulWidget {
  const _SignedIn({super.key, required this.uid});
  final String uid;

  @override
  State<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends State<_SignedIn> {
  late final Store store = Store(widget.uid);

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (store.error != null) {
          return _Message(
            text: "Couldn't load your data: ${store.error}",
            action: TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Sign out')),
          );
        }
        if (!store.ready) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return HomeShell(store: store);
      },
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
          const AccountPage(),
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
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.darkGreen),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: AppColors.muted),
                const SizedBox(height: 12),
                Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
