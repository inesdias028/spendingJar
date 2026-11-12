import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'jar_page.dart';
import 'main.dart';

/// Sign in / create account screen.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false; // false = sign in, true = create account
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _info;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _message(e.code));
    } catch (_) {
      setState(() => _error = "Something went wrong. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@')) {
      setState(() => _error = 'Enter your email address.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    if (_creating && password.length < 6) {
      setState(() => _error = 'Use at least 6 characters for your password.');
      return;
    }
    await _run(() async {
      if (_creating) {
        await _auth.createUserWithEmailAndPassword(email: email, password: password);
      } else {
        await _auth.signInWithEmailAndPassword(email: email, password: password);
      }
    });
  }

  Future<void> _google() async {
    await _run(() async {
      await _auth.signInWithPopup(GoogleAuthProvider());
    });
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Type your email above first, then tap "Forgot password?" again');
      return;
    }
    await _run(() async {
      await _auth.sendPasswordResetEmail(email: email);
      setState(() => _info = 'We sent a reset link to $email. Check your inbox.');
    });
  }

  static String _message(String code) {
    switch (code) {
      case 'invalid-email':
        return "That email address doesn't look right.";
      case 'user-disabled':
        return 'This account has been turned off.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return "Email or password is wrong. Try again or reset your password.";
      case 'email-already-in-use':
        return 'There is already an account with this email. Sign in instead.';
      case 'weak-password':
        return 'Use at least 6 characters for your password.';
      case 'too-many-requests':
        return 'Too many tries. Wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No internet connection. Connect and try again.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Google sign-in was closed before it finished.';
      case 'popup-blocked':
        return 'Your browser blocked the Google window. Allow pop-ups and try again.';
      case 'unauthorized-domain':
        return "This website isn't allowed to sign in yet (add it in Firebase → Authentication → Settings → Authorized domains).";
      case 'operation-not-allowed':
        return 'This sign-in method is not turned on in Firebase yet.';
      default:
        return 'Sign-in failed ($code).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: JarGraphic(fill: 0.75, color: AppColors.green)),
                  const SizedBox(height: 18),
                  const Text('Spending Jar',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
                  const SizedBox(height: 4),
                  Text(
                    _creating ? 'Create your account' : 'Sign in to see your battery',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, fontSize: 17),
                  ),
                  const SizedBox(height: 28),

                  InsetCard(
                    child: Column(
                      children: [
                        CupertinoTextField(
                          controller: _email,
                          placeholder: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 14),
                            child: Icon(CupertinoIcons.mail, color: AppColors.muted, size: 20),
                          ),
                          padding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
                          decoration: null,
                          clearButtonMode: OverlayVisibilityMode.editing,
                          onChanged: (_) => _clearMessages(),
                        ),
                        const RowDivider(indent: 44),
                        CupertinoTextField(
                          controller: _password,
                          placeholder: 'Password',
                          obscureText: !_showPassword,
                          autocorrect: false,
                          autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 14),
                            child: Icon(CupertinoIcons.lock, color: AppColors.muted, size: 20),
                          ),
                          suffix: CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                            child: Icon(_showPassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                                size: 20, color: AppColors.muted),
                          ),
                          padding: const EdgeInsets.fromLTRB(10, 14, 4, 14),
                          decoration: null,
                          onChanged: (_) => _clearMessages(),
                        ),
                      ],
                    ),
                  ),

                  if (!_creating)
                    Align(
                      alignment: Alignment.centerRight,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        onPressed: _busy ? null : _forgotPassword,
                        child: const Text('Forgot password?', style: TextStyle(fontSize: 15)),
                      ),
                    )
                  else
                    const SizedBox(height: 14),

                  if (_error != null) _Notice(text: _error!, color: AppColors.red),
                  if (_info != null) _Notice(text: _info!, color: AppColors.darkGreen),

                  const SizedBox(height: 6),
                  CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : Text(_creating ? 'Create Account' : 'Sign In',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),

                  if (kIsWeb) ...[
                    const SizedBox(height: 18),
                    const Row(children: [
                      Expanded(child: RowDivider(indent: 0)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: TextStyle(color: AppColors.muted, fontSize: 15)),
                      ),
                      Expanded(child: RowDivider(indent: 0)),
                    ]),
                    const SizedBox(height: 18),
                    CupertinoButton(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      onPressed: _busy ? null : _google,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('G', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF4285F4))),
                          SizedBox(width: 10),
                          Text('Continue with Google',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.text)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  CupertinoButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _creating = !_creating;
                              _clearMessages();
                            }),
                    child: Text(
                      _creating ? 'Already have an account? Sign in' : 'New here? Create an account',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _clearMessages() {
    if (_error != null || _info != null) {
      setState(() {
        _error = null;
        _info = null;
      });
    }
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 15)),
    );
  }
}

/// Account tab: who is signed in, and sign out.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Unknown';
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const LargeTitle('Account'),
          InsetCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
                  child: Text(
                    email.isNotEmpty ? email[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Signed in as', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      Text(email, style: const TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Your spending is saved to your account, so it shows up on any phone or computer where you sign in.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 28),
          InsetCard(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: () async {
                if (await confirmIos(context, 'Sign out?', ok: 'Sign Out')) {
                  await FirebaseAuth.instance.signOut();
                }
              },
              child: const Text('Sign Out', style: TextStyle(color: AppColors.red, fontSize: 17)),
            ),
          ),
        ],
      ),
    );
  }
}
