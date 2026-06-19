import '../../domain/entities/symbol.dart';
import '../../domain/entities/candle.dart';
import '../../domain/repositories/markets_repo.dart';
import '../datasources/markets_api_ds.dart';
import '../datasources/markets_mock_ds.dart';

class MarketsRepoImpl implements MarketsRepo {
  final MarketsMockDataSource ds;
  final MarketsApiDataSource api;
  MarketsRepoImpl(this.ds, this.api);

  // All symbols that have a live backend stream (Binance crypto + YF metals/FX)
  static const Set<String> _liveSupported = {
    // Crypto (Binance)
    "BTCUSD", "ETHUSD", "BNBUSD",
    "BTC/USDT", "ETH/USDT", "BNB/USDT",
    // Metals (Yahoo Finance)
    "XAUUSD", "XAGUSD", "XPTUSD",
    // FX (Yahoo Finance)
    "EURUSD", "GBPUSD", "EURGBP",
    // Stocks (Yahoo Finance)
    "AAPL", "AMZN", "TSLA",
  };

  bool _supportsLive(String symbolCode) {
    return _liveSupported.contains(symbolCode.trim().toUpperCase());
  }

  /// Fetch symbols and enrich them with live prices from the backend.
  /// Works for ALL categories: crypto (Binance) + metals/FX (Yahoo Finance).
  @override
  Future<List<SymbolEntity>> getSymbols(MarketCategory category) async {
    final base = await ds.getSymbols(category);
    final updated = <SymbolEntity>[];

    for (final s in base) {
      if (!_supportsLive(s.code)) {
        updated.add(s);
        continue;
      }
      try {
        // Boot the stream (idempotent — backend ignores if already running)
        await api.startStream(s.code).catchError((_) {});
        final priceData = await api.getPrice(s.code);
        final price = (priceData['price'] as num?)?.toDouble();
        if (price != null && price > 0 && price.isFinite) {
          final spread = price * 0.00015; // ~0.015% spread
          updated.add(SymbolEntity(
            code: s.code,
            name: s.name,
            bid: price - spread,
            ask: price + spread,
            isUp: (price - spread) >= s.bid,
          ));
          continue;
        }
      } catch (_) {
        // API unreachable — fall back to mock
      }
      updated.add(s);
    }
    return updated;
  }

  @override
  Future<List<CandleEntity>> getCandles(String symbolCode, {String timeframe = '1h'}) {
    if (_supportsLive(symbolCode)) {
      return api.getCandles(symbolCode, timeframe: timeframe);
    }
    return ds.getCandles(symbolCode);
  }

  @override
  Future<void> startStream(String symbolCode) async {
    if (_supportsLive(symbolCode)) {
      await api.startStream(symbolCode);
    }
  }

  Future<void> loadHistory(String symbolCode) async {
    if (!_supportsLive(symbolCode)) return;
    await api.loadHistory(symbolCode);
  }

  Future<void> loadHistoryWithTimeframe(String symbolCode, String timeframe, {int? horizon}) async {
    if (!_supportsLive(symbolCode)) return;
    await api.loadHistoryWithTimeframe(symbolCode, timeframe, horizon: horizon);
  }

  @override
  Future<void> stopStream(String symbolCode) async {
    if (!_supportsLive(symbolCode)) return;
    await api.stopStream(symbolCode);
  }

  @override
  Future<Map<String, dynamic>> getPrice(String symbolCode) async {
    if (_supportsLive(symbolCode)) {
      return api.getPrice(symbolCode);
    }
    final candles = await ds.getCandles(symbolCode);
    final last = candles.isNotEmpty ? candles.last.close : 0.0;
    return {
      "type": "live_price",
      "price": last,
      "time": DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> getSignal(String symbolCode) async {
    if (_supportsLive(symbolCode)) {
      return api.getSignal(symbolCode);
    }
    return {
      "type": "signal",
      "signal": "HOLD",
      "buy_prob": 0.5,
      "sell_prob": 0.5,
    };
  }
}