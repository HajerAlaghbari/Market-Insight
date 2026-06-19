import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool sending = false;
  String? errorText;
  bool sentOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSendOnce());
  }

  Future<void> _autoSendOnce() async {
    if (sentOnce) return;
    sentOnce = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (user.emailVerified) return;

    await _resendEmail(showSnack: false);
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-not-found':
        return 'User not found.';
      default:
        return e.message ?? e.code;
    }
  }

  Future<void> _resendEmail({bool showSnack = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      sending = true;
      errorText = null;
    });

    try {
      await user.sendEmailVerification();

      if (!mounted) return;

      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Verification email sent (check Inbox/Spam)"),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => errorText = _friendlyAuthError(e));
    } catch (e) {
      if (mounted) setState(() => errorText = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _checkVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => errorText = null);

    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;

      if (refreshed?.emailVerified == true) {
        if (mounted) context.go('/fx');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Email not verified yet")),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => errorText = e.toString());
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Email"),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    /// الشعار
                    Image.asset(
                      "assets/images/logo.png",
                      width: 130,
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      "We sent a verification email to:",
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 6),

                    Text(
                      user?.email ?? "-",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      "Check Inbox and Spam/Junk folder.\nAfter verifying, press the button below.",
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 14),

                    if (errorText != null) ...[
                      Text(
                        errorText!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _checkVerification,
                        child: const Text("I Verified My Email"),
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: sending ? null : () => _resendEmail(),
                      child: sending
                          ? const Text("Sending...")
                          : const Text("Resend Email"),
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
}