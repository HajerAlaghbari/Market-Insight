import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthListenable extends ChangeNotifier {
  AuthListenable() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _sub;

  User? get user => FirebaseAuth.instance.currentUser;
  bool get isLoggedIn => user != null;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}