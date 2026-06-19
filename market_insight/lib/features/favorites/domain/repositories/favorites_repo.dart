abstract class FavoritesRepo {
  Stream<Set<String>> watchFavoriteCodes();
  Future<void> toggleFavorite({required String code, required String name});
}