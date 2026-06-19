import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/favorites_firestore_ds.dart';
import '../../data/repositories/favorites_repo_impl.dart';
import '../../domain/repositories/favorites_repo.dart';

final favoritesRepoProvider = Provider<FavoritesRepo>((ref) {
  return FavoritesRepoImpl(FavoritesFirestoreDataSource());
});

final favoriteCodesProvider = StreamProvider<Set<String>>((ref) {
  return ref.read(favoritesRepoProvider).watchFavoriteCodes();
});

/// ⭐ Toggle favorite action
final toggleFavoriteProvider = Provider((ref) {
  final repo = ref.read(favoritesRepoProvider);

  return ({required String code, required String name}) {
    return repo.toggleFavorite(code: code, name: name);
  };
});