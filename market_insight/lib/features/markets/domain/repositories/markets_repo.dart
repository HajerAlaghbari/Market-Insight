import '../entities/symbol.dart';
import '../entities/candle.dart';

abstract class MarketsRepo {
  Future<List<SymbolEntity>> getSymbols(MarketCategory category);
  Future<List<CandleEntity>> getCandles(String symbolCode, {String timeframe = '1h'});
  Future<void> startStream(String symbolCode);
  Future<void> stopStream(String symbolCode);
  Future<void> loadHistory(String symbolCode);
  Future<void> loadHistoryWithTimeframe(String symbolCode, String timeframe, {int? horizon});
  Future<Map<String, dynamic>> getPrice(String symbolCode);
  Future<Map<String, dynamic>> getSignal(String symbolCode);
}