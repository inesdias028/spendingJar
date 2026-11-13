import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

/// iOS system colours.
class AppColors {
  static const background = Color(0xFFF2F2F7); // systemGroupedBackground
  static const card = Colors.white;
  static const green = Color(0xFF34C759);
  static const darkGreen = Color(0xFF248A3D);
  static const orange = Color(0xFFFF9500);
  static const red = Color(0xFFFF3B30);
  static const blue = Color(0xFF007AFF);
  static const track = Color(0xFFE5E5EA);
  static const text = Color(0xFF000000);
  static const muted = Color(0xFF8A8A8E);
  static const separator = Color(0xFFD1D1D6);
}

class SpendingJarApp extends StatelessWidget {
  const SpendingJarApp({super.key, this.startupError});
  final String? startupError;

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      platform: TargetPlatform.iOS,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue, surface: AppColors.background),
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      fontFamily: GoogleFonts.inter().fontFamily,
    );
    return MaterialApp(
      title: 'Spending Jar',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        cupertinoOverrideTheme: CupertinoThemeData(
          primaryColor: AppColors.blue,
          scaffoldBackgroundColor: AppColors.background,
          textTheme: CupertinoTextThemeData(
            primaryColor: AppColors.blue,
            textStyle: GoogleFonts.inter(fontSize: 17, color: AppColors.text, letterSpacing: -0.4),
            tabLabelTextStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
          ),
        ),
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
          return const Scaffold(body: Center(child: CupertinoActivityIndicator(radius: 14)));
        }
        final user = snap.data;
        if (user == null) return const AuthPage();
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

class _SignedInState extends State<_SignedIn> with WidgetsBindingObserver {
  late final Store store = Store(widget.uid);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  // Coming back to the app: add any recurring spending that is now due.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && store.ready) store.runRecurring();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            action: CupertinoButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Sign out'),
            ),
          );
        }
        if (!store.ready) {
          return const Scaffold(body: Center(child: CupertinoActivityIndicator(radius: 14)));
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
      // Extra space under the bar lifts the buttons away from the bottom edge.
      bottomNavigationBar: Container(
        color: const Color(0xFFF9F9F9),
        padding: const EdgeInsets.only(bottom: 14),
        child: CupertinoTabBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          height: 68,
          iconSize: 34,
          activeColor: AppColors.blue,
          inactiveColor: AppColors.muted,
          backgroundColor: const Color(0xFFF9F9F9),
          items: const [
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.home), label: 'Jar'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_bar), label: 'Stats'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_crop_circle), label: 'Account'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared iOS-style pieces
// ---------------------------------------------------------------------------

/// Big bold page title, like iOS "large titles".
class LargeTitle extends StatelessWidget {
  const LargeTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small grey heading above a group, like in iOS Settings.
class GroupHeader extends StatelessWidget {
  const GroupHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 7),
      child: Text(text.toUpperCase(),
          style: const TextStyle(fontSize: 13, color: AppColors.muted, letterSpacing: 0.1)),
    );
  }
}

/// White rounded box that holds a group of rows.
class InsetCard extends StatelessWidget {
  const InsetCard({super.key, required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }
}

/// Thin line between rows, indented like iOS lists.
class RowDivider extends StatelessWidget {
  const RowDivider({super.key, this.indent = 16});
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: indent),
      height: 0.5,
      color: AppColors.separator,
    );
  }
}

/// An iOS-style sheet that slides up from the bottom, with Cancel and a Done button.
class IosSheet extends StatelessWidget {
  const IosSheet({
    super.key,
    required this.title,
    required this.child,
    required this.onDone,
    this.doneLabel = 'Done',
  });

  final String title;
  final Widget child;
  final VoidCallback onDone;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(color: AppColors.separator, borderRadius: BorderRadius.circular(3)),
                ),
                Row(
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    Expanded(
                      child: Text(title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                    CupertinoButton(
                      onPressed: onDone,
                      child: Text(doneLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS alert with Cancel and a confirm button. Returns true when confirmed.
Future<bool> confirmIos(BuildContext context, String title,
    {String? message, String ok = 'Delete', bool destructive = true}) async {
  final res = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          isDefaultAction: !destructive,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return res ?? false;
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
                const Icon(CupertinoIcons.exclamationmark_triangle, size: 44, color: AppColors.muted),
                const SizedBox(height: 12),
                Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                if (action != null) ...[const SizedBox(height: 8), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
