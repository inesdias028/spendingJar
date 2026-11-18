import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'balance_page.dart';
import 'main.dart';
import 'models.dart';
import 'recurring_page.dart';

/// Where the privacy policy is published (privacy.html, deployed with the site).
const privacyPolicyUrl = 'https://inesdias028.github.io/spendingJar/privacy.html';

/// Account tab: who is signed in, balance settings, privacy, sign out and delete account.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final email = store.demo ? 'you@example.com' : (FirebaseAuth.instance.currentUser?.email ?? 'Unknown');
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => LargeTitlePage(
        title: 'Account',
        children: [
          InsetSection(
            children: [
              CupertinoListTile(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                leadingSize: 56,
                leading: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFA1A1A6), Color(0xFF7C7C80)],
                    ),
                  ),
                  child: Text(
                    email.isNotEmpty ? email[0].toUpperCase() : '?',
                    style: const TextStyle(color: CupertinoColors.white, fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                ),
                title: Text(email, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                subtitle: const Text('Synced to your account'),
              ),
            ],
          ),
          InsetSection(
            header: const SectionHeader('Balance'),
            children: [
              CupertinoListTile(
                leading: const _CircleIcon(CupertinoIcons.money_euro),
                title: const Text('Starting Balance'),
                additionalInfo: Text(signedEuro(store.startBalance)),
                trailing: const CupertinoListTileChevron(),
                onTap: () => presentSheet<void>(context, (_, c) => BalanceSheet(store: store, controller: c)),
              ),
              CupertinoListTile(
                leading: const _CircleIcon(CupertinoIcons.repeat),
                title: const Text('Recurring'),
                additionalInfo: Text('${store.recurring.length}'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => presentSheet<void>(context, (_, c) => RecurringSheet(store: store, controller: c)),
              ),
            ],
          ),
          const GroupFooter(
            'Your entries are saved to your account, so they show up on any phone or computer where you sign in, including the Even iPhone app.',
          ),
          InsetSection(
            children: [
              CupertinoListTile(
                leading: const _CircleIcon(CupertinoIcons.hand_raised_fill),
                title: Text('Privacy Policy', style: TextStyle(color: AppColors.accent.of(context))),
                onTap: () => launchUrl(Uri.parse(privacyPolicyUrl), webOnlyWindowName: '_blank'),
              ),
            ],
          ),
          InsetSection(
            hasLeading: false,
            children: [
              CupertinoListTile(
                title: Center(child: Text('Sign Out', style: TextStyle(color: AppColors.red.of(context)))),
                onTap: () async {
                  if (await confirmIos(context, 'Sign out?', ok: 'Sign Out')) {
                    await FirebaseAuth.instance.signOut();
                  }
                },
              ),
            ],
          ),
          if (!store.demo) ...[
            InsetSection(
              hasLeading: false,
              children: [
                CupertinoListTile(
                  title: Center(child: Text('Delete Account', style: TextStyle(color: AppColors.red.of(context)))),
                  onTap: () => _deleteAccount(context),
                ),
              ],
            ),
            const GroupFooter(
              'Deletes your account and all your entries, on the website and on the iPhone app. This can’t be undone.',
            ),
          ],
        ],
      ),
    );
  }

  /// Asks to confirm, checks it's really you (password or Google), then deletes
  /// all data in Firestore and finally the sign-in account.
  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ok = await confirmIos(
      context,
      'Delete your account?',
      message: 'Your balance, entries, categories and recurring items are deleted for good, on every device.',
      ok: 'Delete',
    );
    if (!ok || !context.mounted) return;
    try {
      final providers = user.providerData.map((p) => p.providerId).toSet();
      if (providers.contains('password')) {
        final password = await _askPassword(context);
        if (password == null || password.isEmpty) return;
        await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password));
      } else if (providers.contains('google.com')) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
      }
      if (context.mounted) showToast(context, 'Deleting your account…');
      await store.deleteAllData();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      final message = switch (e.code) {
        'wrong-password' || 'invalid-credential' || 'INVALID_LOGIN_CREDENTIALS' => 'That password is wrong.',
        'popup-closed-by-user' || 'cancelled-popup-request' => 'Google sign-in was closed before it finished.',
        'too-many-requests' => 'Too many tries. Wait a few minutes and try again.',
        'network-request-failed' => 'No internet connection. Connect and try again.',
        _ => e.message ?? e.code,
      };
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Couldn’t delete the account'),
          content: Text(message),
          actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    }
  }

  Future<String?> _askPassword(BuildContext context) {
    final controller = TextEditingController();
    return showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Enter your password'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              const Text('To keep your account safe, confirm it’s you.'),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: controller,
                placeholder: 'Password',
                obscureText: true,
                autofocus: true,
                onSubmitted: (_) => Navigator.pop(ctx, controller.text),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// White symbol on an Even-teal circle, like the iPhone app's rows.
class _CircleIcon extends StatelessWidget {
  const _CircleIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(color: AppColors.accent.of(context), shape: BoxShape.circle),
      child: Icon(icon, color: CupertinoColors.white, size: 17),
    );
  }
}
