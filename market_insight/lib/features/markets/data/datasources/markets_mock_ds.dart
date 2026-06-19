import '../../domain/entities/symbol.dart';
import '../../domain/entities/candle.dart';

class MarketsMockDataSource {
  Future<List<SymbolEntity>> getSymbols(MarketCategory category) async {
    await Future.delayed(const Duration(milliseconds: 200));

    switch (category) {
      case MarketCategory.fx:
        return const [
          SymbolEntity(code: "EURUSD", name: "EUR / USD", bid: 1.17973, ask: 1.17979, isUp: true),
          SymbolEntity(code: "GBPUSD", name: "GBP / USD", bid: 1.34868, ask: 1.34879, isUp: true),
          SymbolEntity(code: "EURGBP", name: "EUR / GBP", bid: 0.8730, ask: 0.8732, isUp: false),
        ];
      case MarketCategory.metals:
        return const [
          SymbolEntity(code: "XAUUSD", name: "Gold (USD)", bid: 5194.01, ask: 5195.08, isUp: true),
          SymbolEntity(code: "XAGUSD", name: "Silver (USD)", bid: 58.12, ask: 58.20, isUp: true),
          SymbolEntity(code: "XPTUSD", name: "Platinum (USD)", bid: 982.50, ask: 983.10, isUp: false),
        ];
      case MarketCategory.crypto:
        return const [
          SymbolEntity(code: "BTCUSD", name: "Bitcoin (USD)", bid: 86250, ask: 86280, isUp: true),
          SymbolEntity(code: "ETHUSD", name: "Ethereum (USD)", bid: 4680, ask: 4685, isUp: false),
          SymbolEntity(code: "BNBUSD", name: "BNB (USD)", bid: 612, ask: 614, isUp: true),
        ];
      case MarketCategory.stocks:
        return const [
          SymbolEntity(code: "AAPL", name: "Apple Inc.", bid: 178.50, ask: 178.65, isUp: true),
          SymbolEntity(code: "AMZN", name: "Amazon.com", bid: 182.30, ask: 182.45, isUp: true),
          SymbolEntity(code: "TSLA", name: "Tesla Inc.", bid: 245.80, ask: 246.10, isUp: false),
        ];
    }
  }

  Future<List<CandleEntity>> getCandles(String code, {String timeframe = '1h'}) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final now = DateTime.now();
    double base = switch (code) {
      "XAUUSD" => 5180,
      "XAGUSD" => 58,
      "XPTUSD" => 982,
      "BTCUSD" => 86000,
      "ETHUSD" => 4700,
      "BNBUSD" => 612,
      "AAPL" => 178,
      "AMZN" => 182,
      "TSLA" => 245,
      "EURGBP" => 0.873,
      _ => 1.2,
    };

    final candles = <CandleEntity>[];
    for (int i = 80; i >= 0; i--) {
      final t = now.subtract(Duration(hours: i));
      final open = base + (i % 7 - 3) * (base * 0.0008);
      final close = open + ((i % 5) - 2) * (base * 0.0006);
      final high = (open > close ? open : close) + (base * 0.0012);
      final low = (open < close ? open : close) - (base * 0.0012);

      candles.add(CandleEntity(time: t, open: open, high: high, low: low, close: close));
      base = close;
    }
    return candles;
  }
}