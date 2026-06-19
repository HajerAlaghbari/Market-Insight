import '../../domain/repositories/favorites_repo.dart';
import '../datasources/favorites_firestore_ds.dart';

class FavoritesRepoImpl implements FavoritesRepo {
  final FavoritesFirestoreDataSource ds;
  FavoritesRepoImpl(this.ds);

  @override
  Stream<Set<String>> watchFavoriteCodes() => ds.watchFavoriteCodes();

  @override
  Future<void> toggleFavorite({required String code, required String name}) {
    return ds.toggleFavorite(code: code, name: name);
  }
}