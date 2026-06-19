import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/markets_api_ds.dart';
import '../../data/datasources/markets_mock_ds.dart';
import '../../data/repositories/markets_repo_impl.dart';
import '../../domain/entities/candle.dart';
import '../../domain/entities/symbol.dart';
import '../../domain/repositories/markets_repo.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────────────────────────────────────
final marketsRepoProvider = Provider<MarketsRepo>((ref) {
  return MarketsRepoImpl(MarketsMockDataSource(), MarketsApiDataSource());
});

// ─────────────────────────────────────────────────────────────────────────────
// LIST PAGE — streams live Bid/Ask for every symbol every 3 s
// Crypto → Binance   |   Metals/FX → Yahoo Finance   (via backend)
// ─────────────────────────────────────────────────────────────────────────────
final symbolsProvider =
    StreamProvider.family<List<SymbolEntity>, MarketCategory>(
        (ref, category) async* {
  while (true) {
    try {
      yield await ref.read(marketsRepoProvider).getSymbols(category);
    } catch (_) {
      // Continue on error, don't crash
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL PAGE — boots the backend stream once when user opens a symbol page.
// FutureProvider: resolves once, cached by Riverpod while the page is alive,
// disposed when user navigates away (no lingering boot calls).
// ─────────────────────────────────────────────────────────────────────────────
final symbolBootProvider =
    FutureProvider.family<void, String>((ref, code) async {
  try {
    await ref.read(marketsRepoProvider).startStream(code);
  } catch (_) {
    // If backend is unreachable, we still proceed (mock fallback)
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL PAGE — refreshes candles every 5 s so chart stays live
// Accepts both symbol code and timeframe as parameters
// ─────────────────────────────────────────────────────────────────────────────
final candlesProvider = StreamProvider.family<List<CandleEntity>, ({String code, String timeframe})>(
  (ref, params) async* {
    // Small delay to allow backend to start loading data
    await Future<void>.delayed(const Duration(milliseconds: 500));

    while (true) {
      try {
        yield await ref.read(marketsRepoProvider).getCandles(params.code, timeframe: params.timeframe);
      } catch (_) {
        // Don't crash — just retry next cycle
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL PAGE — live price only, updates every 1 s
// Signal is NOT fetched here — it is fetched only on candle close
// ─────────────────────────────────────────────────────────────────────────────
final liveMarketProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, code) async* {
  // Wait for the backend stream to be booted first
  await ref.read(symbolBootProvider(code).future);

  while (true) {
    try {
      final repo = ref.read(marketsRepoProvider);
      final price = await repo.getPrice(code);
      yield {
        'price': price['price'],
      };
    } catch (_) {
      // Keep streaming on error
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
});