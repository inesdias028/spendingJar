import 'dart:ui' show ImageFilter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

import 'account_page.dart';
import 'auth_page.dart';
import 'balance_page.dart';
import 'firebase_options.dart';
import 'models.dart';
import 'stats_page.dart';

/// Build with `--dart-define=DEMO=true` to open straight into sample data, without Firebase.
const demoMode = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  if (demoMode) {
    // Nothing to set up.
  } else if (!DefaultFirebaseOptions.isConfigured) {
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

/// iOS system colours. They switch automatically between light and dark mode;
/// use `.of(context)` where a plain colour is needed (for example in a BoxDecoration).
class AppColors {
  static const background = CupertinoColors.systemGroupedBackground;
  static const card = CupertinoColors.secondarySystemGroupedBackground;
  static const green = CupertinoColors.systemGreen;
  static const red = CupertinoColors.systemRed;
  static const orange = CupertinoColors.systemOrange;
  /// Even teal, the accent colour of the iPhone app (a bit lighter in dark mode).
  static const accent = CupertinoDynamicColor.withBrightness(color: Color(0xFF1F8A8A), darkColor: Color(0xFF3DB8B2));

  /// Buttons and links use the accent colour (the name stays for older code).
  static const blue = accent;
  static const label = CupertinoColors.label;
  static const muted = CupertinoColors.secondaryLabel;
  static const faint = CupertinoColors.tertiaryLabel;
  static const separator = CupertinoColors.separator;
  static const fill = CupertinoColors.tertiarySystemFill;
  static const track = CupertinoColors.systemFill;

  /// Text colour for money: green when positive, red when negative.
  static Color money(BuildContext context, double v) =>
      (v > 0.004 ? green : (v < -0.004 ? red : label)).of(context);
}

extension ResolveColor on Color {
  /// The light or dark version of an iOS dynamic colour.
  Color of(BuildContext context) => CupertinoDynamicColor.resolve(this, context);
}

class SpendingJarApp extends StatelessWidget {
  const SpendingJarApp({super.key, this.startupError});
  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Even',
      debugShowCheckedModeBanner: false,
      // No brightness set: it follows the phone's light / dark mode.
      theme: const CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          tabLabelTextStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
            color: CupertinoColors.inactiveGray,
          ),
        ),
        primaryColor: AppColors.accent,
        scaffoldBackgroundColor: AppColors.background,
        barBackgroundColor: CupertinoColors.systemGroupedBackground,
      ),
      home: startupError != null
          ? MessagePage(text: startupError!)
          : (demoMode ? HomeShell(store: Store.demo()) : const AuthGate()),
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
        if (snap.connectionState == ConnectionState.waiting) return const _Loading();
        final user = snap.data;
        if (user == null) return const AuthPage();
        return _SignedIn(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: CupertinoActivityIndicator(radius: 14)));
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

  // Coming back to the app: add any recurring money that is now due.
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
          return MessagePage(
            text: "Couldn't load your data: ${store.error}",
            action: CupertinoButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Sign Out'),
            ),
          );
        }
        if (!store.ready) return const _Loading();
        return HomeShell(store: store);
      },
    );
  }
}

/// The three tabs, with a floating "glass" tab bar like the iPhone app (iOS 26).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final Store store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  final _navigators = List.generate(3, (_) => GlobalKey<NavigatorState>());

  static const _items = [
    (CupertinoIcons.creditcard, CupertinoIcons.creditcard_fill, 'Balance'),
    (CupertinoIcons.chart_bar, CupertinoIcons.chart_bar_fill, 'Stats'),
    (CupertinoIcons.person_crop_circle, CupertinoIcons.person_crop_circle_fill, 'Account'),
  ];

  void _select(int i) {
    if (i == _tab) {
      // Tapping the open tab again goes back to its first screen.
      _navigators[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _tab = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Home-screen web apps often report no safe area; keep the bar off the bottom edge anyway.
    final bottom = mq.viewPadding.bottom < 14 ? 14.0 : mq.viewPadding.bottom;
    const barHeight = 62.0;
    final reserved = bottom + barHeight + 12;
    final pages = [
      BalancePage(store: widget.store),
      StatsPage(store: widget.store),
      AccountPage(store: widget.store),
    ];
    return Stack(
      children: [
        // Pages leave room at the bottom for the floating bar.
        MediaQuery(
          data: mq.copyWith(
            padding: mq.padding.copyWith(bottom: reserved),
            viewPadding: mq.viewPadding.copyWith(bottom: reserved),
          ),
          child: IndexedStack(
            index: _tab,
            children: [
              for (var i = 0; i < 3; i++)
                CupertinoTabView(navigatorKey: _navigators[i], builder: (_) => pages[i]),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottom,
          child: Center(
            child: GlassTabBar(items: _items, current: _tab, onTap: _select, height: barHeight),
          ),
        ),
      ],
    );
  }
}

/// A floating, frosted capsule with the tab buttons; the open tab sits on a soft pill.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({super.key, required this.items, required this.current, required this.onTap, this.height = 62});
  final List<(IconData, IconData, String)> items;
  final int current;
  final ValueChanged<int> onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final glass = const CupertinoDynamicColor.withBrightness(color: Color(0xC7FFFFFF), darkColor: Color(0xB82C2C2E)).of(context);
    final edge = const CupertinoDynamicColor.withBrightness(color: Color(0x14000000), darkColor: Color(0x24FFFFFF)).of(context);
    final pill = const CupertinoDynamicColor.withBrightness(color: Color(0x12000000), darkColor: Color(0x1FFFFFFF)).of(context);
    final radius = BorderRadius.circular(height / 2);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: height,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: glass, borderRadius: radius, border: Border.all(color: edge, width: 0.5)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: 88,
                      decoration: BoxDecoration(
                        color: i == current ? pill : const Color(0x00000000),
                        borderRadius: BorderRadius.circular((height - 8) / 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            i == current ? items[i].$2 : items[i].$1,
                            size: 25,
                            color: (i == current ? AppColors.accent : AppColors.label).of(context),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].$3,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: (i == current ? AppColors.accent : AppColors.label).of(context),
                            ),
                          ),
                        ],
                      ),
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

/// A round "glass" button for the top bar, like the iPhone app's toolbar buttons.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onPressed, this.label});
  final IconData icon;
  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.card.of(context),
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Icon(icon, size: 21, color: AppColors.label.of(context)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared iOS-style pieces
// ---------------------------------------------------------------------------

/// A tab's page: grouped background with a big title that shrinks into the
/// navigation bar as you scroll, like Settings, Wallet or Health.
class LargeTitlePage extends StatelessWidget {
  const LargeTitlePage({super.key, required this.title, required this.children, this.trailing, this.controller});
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: CustomScrollView(
        controller: controller,
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            trailing: trailing,
            stretch: true,
            border: null,
            backgroundColor: const CupertinoDynamicColor.withBrightness(
              color: Color(0xE6F2F2F7),
              darkColor: Color(0xE6000000),
            ),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.only(bottom: 24),
              sliver: SliverList(delegate: SliverChildListDelegate(children)),
            ),
          ),
        ],
      ),
    );
  }
}

/// White (or dark grey) rounded box, the same as an inset grouped list.
class InsetCard extends StatelessWidget {
  const InsetCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.margin});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 20),
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.card.of(context), borderRadius: BorderRadius.circular(kCardRadius)),
      child: child,
    );
  }
}

/// Corner radius of cards and grouped lists (iOS 26 uses big, soft corners).
const double kCardRadius = 22;

/// A group of rows on a rounded card, with an optional header and footer,
/// like an inset grouped list on iOS 26.
class InsetSection extends StatelessWidget {
  const InsetSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.margin,
    this.hasLeading = true,
  });

  final List<Widget> children;
  final Widget? header;
  final Widget? footer;
  final EdgeInsetsGeometry? margin;

  /// Rows start with an icon or emoji, so dividers start after it.
  final bool hasLeading;

  @override
  Widget build(BuildContext context) {
    final divider = Container(
      margin: EdgeInsets.only(left: hasLeading ? 62 : 16),
      height: 0.5,
      color: AppColors.separator.of(context),
    );
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(padding: const EdgeInsets.fromLTRB(16, 22, 16, 7), child: header!)
          else
            const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(kCardRadius),
            child: ColoredBox(
              color: AppColors.card.of(context),
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) divider,
                    children[i],
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: DefaultTextStyle.merge(
                style: TextStyle(fontSize: 13, color: AppColors.muted.of(context)),
                child: footer!,
              ),
            ),
        ],
      ),
    );
  }
}

/// Small grey heading above a group, like in iOS Settings.
class GroupHeader extends StatelessWidget {
  const GroupHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 22, 36, 7),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: headerStyle(context)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Grey sentence-case heading style above groups (iOS 26).
TextStyle headerStyle(BuildContext context) =>
    TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.2, color: AppColors.muted.of(context));

/// Header for an [InsetSection].
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: headerStyle(context),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small grey note under a group.
class GroupFooter extends StatelessWidget {
  const GroupFooter(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 7, 36, 0),
      child: Text(text, style: TextStyle(fontSize: 13, color: (color ?? AppColors.muted).of(context))),
    );
  }
}

/// Emoji in a soft circle, used at the start of list rows.
class EmojiBadge extends StatelessWidget {
  const EmojiBadge(this.emoji, {super.key, this.size = 32});
  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.fill.of(context), borderRadius: BorderRadius.circular(size * 0.28)),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.55)),
    );
  }
}

/// Full-width segmented control (Week / Month / Year, Spend / Income…).
class Segments<T extends Object> extends StatelessWidget {
  const Segments({super.key, required this.value, required this.items, required this.onChanged, this.thumbColor});
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  final Color? thumbColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<T>(
          groupValue: value,
          thumbColor: thumbColor ??
              const CupertinoDynamicColor.withBrightness(color: Color(0xFFFFFFFF), darkColor: Color(0xFF636366)),
          children: {
            for (final e in items.entries)
              e.key: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(e.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
          },
          onValueChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// Opens an iOS 13+ style sheet: the screen behind shrinks back, and it can
/// be dragged down to close.
Future<T?> presentSheet<T>(BuildContext context, Widget Function(BuildContext, ScrollController) builder) {
  return showCupertinoSheet<T>(context: context, scrollableBuilder: builder);
}

/// The inside of a sheet: Cancel, a bold title and a Done button on top.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.controller,
    required this.children,
    this.onDone,
    this.doneLabel = 'Done',
    this.showCancel = true,
  });

  final String title;
  final ScrollController controller;
  final List<Widget> children;
  final VoidCallback? onDone;
  final String doneLabel;
  final bool showCancel;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        transitionBetweenRoutes: false,
        backgroundColor: AppColors.background,
        border: null,
        leading: showCancel
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              )
            : null,
        middle: Text(title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onDone ?? () => Navigator.pop(context),
          child: Text(doneLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          children: children,
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

/// A short message in a dark pill near the top, which fades away (like iOS HUDs).
void showToast(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Toast(message: message, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.onDone});
  final String message;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _c.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    await _c.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 10;
    return Positioned(
      top: top,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _c,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, -0.4), end: Offset.zero)
                .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xEE1C1C1E),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MessagePage extends StatelessWidget {
  const MessagePage({super.key, required this.text, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.exclamationmark_triangle, size: 44, color: AppColors.muted.of(context)),
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
