import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'main.dart';

/// Sign in / create account screen.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
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
    if (!_form.currentState!.validate()) return;
    final email = _email.text.trim();
    final password = _password.text;
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
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.savings, size: 72, color: AppColors.green),
                    const SizedBox(height: 12),
                    const Text('Spending Jar',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      _creating ? 'Create your account' : 'Sign in to see your jar',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted, fontSize: 15),
                    ),
                    const SizedBox(height: 28),

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: _field('Email', Icons.mail_outline),
                      validator: (v) =>
                          (v == null || !v.trim().contains('@')) ? 'Enter your email address' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: _field('Password', Icons.lock_outline).copyWith(
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? 'Hide password' : 'Show password',
                          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter your password';
                        if (_creating && v.length < 6) return 'Use at least 6 characters';
                        return null;
                      },
                    ),

                    if (!_creating)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _forgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      )
                    else
                      const SizedBox(height: 12),

                    if (_error != null) _Notice(text: _error!, color: AppColors.red),
                    if (_info != null) _Notice(text: _info!, color: AppColors.darkGreen),

                    const SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.darkGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text(_creating ? 'Create account' : 'Sign in'),
                    ),

                    // Google sign-in uses a pop-up, which works on the website.
                    if (kIsWeb) ...[
                      const SizedBox(height: 16),
                      const Row(children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or', style: TextStyle(color: AppColors.muted)),
                        ),
                        Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.text,
                          side: const BorderSide(color: Color(0xFFDDD6CB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _busy ? null : _google,
                        icon: const Text('G',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF4285F4))),
                        label: const Text('Continue with Google'),
                      ),
                    ],

                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _creating = !_creating;
                                _error = null;
                                _info = null;
                              }),
                      child: Text(_creating
                          ? 'Already have an account? Sign in'
                          : "New here? Create an account"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _field(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4DDD2))),
      );
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 14)),
    );
  }
}

/// Account tab: who is signed in, and sign out.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE6F2EA),
                  child: Icon(Icons.person, color: AppColors.darkGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Signed in as', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      Text(user?.email ?? 'Unknown', style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your spending is saved to your account, so it shows up on any phone or computer where you sign in.',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: AppColors.red,
              side: const BorderSide(color: Color(0xFFF0C9C9)),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
