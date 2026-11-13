import 'package:firebase_auth/firebase_auth.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

import 'balance_page.dart';
import 'main.dart';
import 'models.dart';
import 'recurring_page.dart';

/// Account tab: who is signed in, balance settings, and sign out.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final email = store.demo ? 'demo@example.com' : (FirebaseAuth.instance.currentUser?.email ?? 'Unknown');
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => LargeTitlePage(
        title: 'Account',
        children: [
          CupertinoListSection.insetGrouped(
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
          CupertinoListSection.insetGrouped(
            header: SectionHeader('Balance'),
            children: [
              CupertinoListTile(
                leading: const _SettingsIcon(CupertinoIcons.money_euro, CupertinoColors.systemGreen),
                title: const Text('Starting Balance'),
                additionalInfo: Text(signedEuro(store.startBalance)),
                trailing: const CupertinoListTileChevron(),
                onTap: () => presentSheet<void>(context, (_, c) => BalanceSheet(store: store, controller: c)),
              ),
              CupertinoListTile(
                leading: const _SettingsIcon(CupertinoIcons.repeat, CupertinoColors.systemBlue),
                title: const Text('Recurring'),
                additionalInfo: Text('${store.recurring.length}'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => presentSheet<void>(context, (_, c) => RecurringSheet(store: store, controller: c)),
              ),
            ],
          ),
          const GroupFooter(
            'Your entries are saved to your account, so they show up on any phone or computer where you sign in.',
          ),
          CupertinoListSection.insetGrouped(
            children: [
              CupertinoListTile(
                title: Center(
                  child: Text('Sign Out', style: TextStyle(color: AppColors.red.of(context))),
                ),
                onTap: () async {
                  if (await confirmIos(context, 'Sign out?', ok: 'Sign Out')) {
                    await FirebaseAuth.instance.signOut();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// White symbol on a coloured rounded square, like the rows in iOS Settings.
class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon, this.color);
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(color: color.of(context), borderRadius: BorderRadius.circular(7)),
      child: Icon(icon, color: CupertinoColors.white, size: 18),
    );
  }
}
