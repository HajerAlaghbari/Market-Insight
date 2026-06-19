import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/favorites_storage.dart';

/// Provider for favorite symbols list
final favoritesProvider = StreamProvider<List<String>>((ref) async* {
  // Initial load
  yield await FavoritesStorage.getFavorites();
  
  // Listen to changes (refresh every 2 seconds to catch updates)
  while (true) {
    await Future.delayed(const Duration(seconds: 2));
    yield await FavoritesStorage.getFavorites();
  }
});

/// Provider to check if a specific symbol is favorite
final isFavoriteProvider = FutureProvider.family<bool, String>((ref, symbol) async {
  return await FavoritesStorage.isFavorite(symbol);
});

/// Provider to toggle favorite status
final toggleFavoriteProvider = Provider((ref) {
  return (String symbol) async {
    final isFav = await FavoritesStorage.toggleFavorite(symbol);
    // Invalidate providers to refresh UI
    ref.invalidate(favoritesProvider);
    ref.invalidate(isFavoriteProvider(symbol));
    return isFav;
  };
});
