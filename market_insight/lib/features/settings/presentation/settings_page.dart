import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) context.go('/login');
  }

  Future<void> _changePassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) return;

    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    bool obscure1 = true;
    bool obscure2 = true;
    bool obscure3 = true;
    String? err;

    String? validateNew(String v) {
      if (v.isEmpty) return 'New password is required';
      if (v.length < 8) return 'Password must be at least 8 characters';
      if (!RegExp(r'[A-Z]').hasMatch(v)) {
        return 'Password must contain at least 1 capital letter';
      }
      return null;
    }

    String friendlyChangePasswordError(FirebaseAuthException e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Current password is incorrect';
        case 'weak-password':
          return 'Weak password';
        case 'too-many-requests':
          return 'Too many requests. Try again later';
        case 'network-request-failed':
          return 'No internet connection';
        case 'requires-recent-login':
          return 'Please login again and try once more';
        default:
          return 'Failed to change password';
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              title: const Text("Change Password"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentCtrl,
                      obscureText: obscure1,
                      decoration: InputDecoration(
                        labelText: "Current password",
                        suffixIcon: IconButton(
                          onPressed: () => setSt(() => obscure1 = !obscure1),
                          icon: Icon(
                            obscure1
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newCtrl,
                      obscureText: obscure2,
                      decoration: InputDecoration(
                        labelText: "New password",
                        helperText: "Min 8 characters + 1 capital letter",
                        suffixIcon: IconButton(
                          onPressed: () => setSt(() => obscure2 = !obscure2),
                          icon: Icon(
                            obscure2
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: obscure3,
                      decoration: InputDecoration(
                        labelText: "Confirm new password",
                        suffixIcon: IconButton(
                          onPressed: () => setSt(() => obscure3 = !obscure3),
                          icon: Icon(
                            obscure3
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    if (err != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        err!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final current = currentCtrl.text;
                    final next = newCtrl.text;
                    final confirm = confirmCtrl.text;

                    if (current.isEmpty) {
                      setSt(() => err = 'Current password is required');
                      return;
                    }

                    final v = validateNew(next);
                    if (v != null) {
                      setSt(() => err = v);
                      return;
                    }

                    if (confirm.isEmpty) {
                      setSt(() => err = 'Confirm password is required');
                      return;
                    }

                    if (next != confirm) {
                      setSt(() => err = 'Passwords do not match');
                      return;
                    }

                    try {
                      final cred = EmailAuthProvider.credential(
                        email: user.email!,
                        password: current,
                      );

                      await user.reauthenticateWithCredential(cred);
                      await user.updatePassword(next);

                      if (ctx.mounted) Navigator.pop(ctx);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Password updated successfully"),
                          ),
                        );
                      }
                    } on FirebaseAuthException catch (e) {
                      setSt(() => err = friendlyChangePasswordError(e));
                    } catch (_) {
                      setSt(() => err = 'Something went wrong. Please try again');
                    }
                  },
                  child: const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );


  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Account",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Email: ${user?.email ?? '-'}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "UID: ${user?.uid ?? '-'}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.lock_reset),
              label: const Text("Change Password"),
              onPressed: user == null ? null : () => _changePassword(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
              onPressed: user == null ? null : () => _logout(context),
            ),
          ),
        ],
      ),
    );
  }
}