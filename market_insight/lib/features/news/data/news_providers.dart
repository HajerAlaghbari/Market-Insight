import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../api_service.dart';
import '../domain/news_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// All news (optionally filtered by category)
// ─────────────────────────────────────────────────────────────────────────────
final newsProvider = StreamProvider.family<List<NewsEntity>, String?>(
  (ref, category) async* {
    while (true) {
      try {
        final data = await ApiService.getNews(
          category: category,
          limit: 100,
        );
        final articles = (data['articles'] as List<dynamic>?) ?? [];
        yield articles
            .map((a) => NewsEntity.fromJson(a as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // Yield empty on error, will retry
        yield <NewsEntity>[];
      }
      await Future<void>.delayed(const Duration(seconds: 60));
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// News for a specific symbol
// ─────────────────────────────────────────────────────────────────────────────
final symbolNewsProvider = StreamProvider.family<List<NewsEntity>, String>(
  (ref, symbolCode) async* {
    while (true) {
      try {
        final data = await ApiService.getNewsForSymbol(symbolCode, limit: 30);
        final articles = (data['articles'] as List<dynamic>?) ?? [];
        yield articles
            .map((a) => NewsEntity.fromJson(a as Map<String, dynamic>))
            .toList();
      } catch (e) {
        yield <NewsEntity>[];
      }
      await Future<void>.delayed(const Duration(seconds: 60));
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// News sentiment impact for a symbol
// ─────────────────────────────────────────────────────────────────────────────
final newsImpactProvider = StreamProvider.family<NewsImpact, String>(
  (ref, symbolCode) async* {
    while (true) {
      try {
        final data = await ApiService.getNewsImpact(symbolCode);
        yield NewsImpact.fromJson(data);
      } catch (e) {
        yield const NewsImpact(
          symbol: '',
          articleCount: 0,
          avgImpact: 0.5,
          sentimentSummary: 'Neutral',
          bullishCount: 0,
          bearishCount: 0,
          neutralCount: 0,
        );
      }
      await Future<void>.delayed(const Duration(seconds: 30));
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Selected category filter state
// ─────────────────────────────────────────────────────────────────────────────
final selectedNewsCategoryProvider = StateProvider<String?>((ref) => null);
