import 'package:shared_preferences/shared_preferences.dart';

/// Local storage for favorite symbols
class FavoritesStorage {
  static const _key = 'favorite_symbols';

  /// Get list of favorite symbols
  static Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  /// Add symbol to favorites
  static Future<void> addFavorite(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_key) ?? [];
    if (!favorites.contains(symbol)) {
      favorites.add(symbol);
      await prefs.setStringList(_key, favorites);
    }
  }

  /// Remove symbol from favorites
  static Future<void> removeFavorite(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_key) ?? [];
    favorites.remove(symbol);
    await prefs.setStringList(_key, favorites);
  }

  /// Toggle favorite status
  static Future<bool> toggleFavorite(String symbol) async {
    final favorites = await getFavorites();
    if (favorites.contains(symbol)) {
      await removeFavorite(symbol);
      return false;
    } else {
      await addFavorite(symbol);
      return true;
    }
  }

  /// Check if symbol is favorite
  static Future<bool> isFavorite(String symbol) async {
    final favorites = await getFavorites();
    return favorites.contains(symbol);
  }
}
