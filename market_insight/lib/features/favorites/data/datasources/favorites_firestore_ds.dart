import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesFirestoreDataSource {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String _uidOrThrow() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _favCol() {
    final uid = _uidOrThrow();
    return _db.collection('users').doc(uid).collection('favorites');
  }

  Stream<Set<String>> watchFavoriteCodes() {
    return _favCol().snapshots().map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  Future<void> toggleFavorite({required String code, required String name}) async {
    final doc = _favCol().doc(code);
    final existing = await doc.get();
    if (existing.exists) {
      await doc.delete();
    } else {
      await doc.set({
        'code': code,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}