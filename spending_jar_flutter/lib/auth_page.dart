import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cupertino_ui/cupertino_ui.dart';

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
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppBadge()),
                  const SizedBox(height: 18),
                  const Text('Spending Jar',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
                  const SizedBox(height: 4),
                  Text(
                    _creating ? 'Create your account' : 'Sign in to see your balance',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted.of(context), fontSize: 17),
                  ),
                  const SizedBox(height: 28),

                  InsetCard(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        CupertinoTextField(
                          controller: _email,
                          placeholder: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          prefix: Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: Icon(CupertinoIcons.mail, color: AppColors.muted.of(context), size: 20),
                          ),
                          padding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
                          decoration: null,
                          clearButtonMode: OverlayVisibilityMode.editing,
                          onChanged: (_) => _clearMessages(),
                        ),
                        Container(margin: const EdgeInsets.only(left: 44), height: 0.5, color: AppColors.separator.of(context)),
                        CupertinoTextField(
                          controller: _password,
                          placeholder: 'Password',
                          obscureText: !_showPassword,
                          autocorrect: false,
                          autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          prefix: Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: Icon(CupertinoIcons.lock, color: AppColors.muted.of(context), size: 20),
                          ),
                          suffix: CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                            child: Icon(_showPassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                                size: 20, color: AppColors.muted.of(context)),
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
                  if (_info != null) _Notice(text: _info!, color: AppColors.green),

                  const SizedBox(height: 6),
                  CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                        : Text(_creating ? 'Create Account' : 'Sign In',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
                  ),

                  if (kIsWeb) ...[
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: Container(height: 0.5, color: AppColors.separator.of(context))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: TextStyle(color: AppColors.muted.of(context), fontSize: 15)),
                      ),
                      Expanded(child: Container(height: 0.5, color: AppColors.separator.of(context))),
                    ]),
                    const SizedBox(height: 18),
                    CupertinoButton(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      onPressed: _busy ? null : _google,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('G',
                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF4285F4))),
                          const SizedBox(width: 10),
                          Text('Continue with Google',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.label.of(context))),
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
        color: color.of(context).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: color.of(context), fontSize: 15)),
    );
  }
}

/// The app's icon, drawn: a green rounded square with a euro sign.
class AppBadge extends StatelessWidget {
  const AppBadge({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.225),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CD964), Color(0xFF248A3D)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Icon(CupertinoIcons.money_euro, color: CupertinoColors.white, size: size * 0.55),
    );
  }
}
