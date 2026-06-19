import '../../../../api_service.dart';
import '../../domain/entities/candle.dart';

class MarketsApiDataSource {
  Future<void> startStream(String symbolCode) {
    return ApiService.startStream(symbolCode);
  }

  Future<void> stopStream(String symbolCode) {
    return ApiService.stopStream(symbolCode);
  }

  Future<void> loadHistory(String symbolCode) {
    return ApiService.loadHistory(symbolCode);
  }

  Future<void> loadHistoryWithTimeframe(String symbolCode, String timeframe, {int? horizon}) {
    return ApiService.loadHistoryWithTimeframe(symbolCode, timeframe, horizon: horizon);
  }

  Future<Map<String, dynamic>> getPrice(String symbolCode) {
    return ApiService.getPrice(symbolCode);
  }

  Future<Map<String, dynamic>> getSignal(String symbolCode) {
    return ApiService.getSignal(symbolCode);
  }

  Future<List<CandleEntity>> getCandles(String symbolCode, {int limit = 200, String timeframe = '1h'}) async {
    final raw = await ApiService.getCandles(symbolCode, limit: limit, timeframe: timeframe);
    return raw.map((item) {
      final row = item as Map<String, dynamic>;
      final ts = row["timestamp"];
      // Convert timestamp to UTC DateTime for accurate chart display
      final dt = ts is int
          ? DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true)
          : DateTime.tryParse(ts.toString()) ?? DateTime.now();

      // Helper to safely convert and validate numbers with strict checks
      double safeDouble(dynamic value, double defaultValue) {
        if (value == null) return defaultValue;
        try {
          final d = (value as num).toDouble();
          // Reject any invalid values
          if (d.isNaN || d.isInfinite || d <= 0) {
            print('⚠️ Invalid candle value detected: $value');
            return defaultValue;
          }
          return d;
        } catch (e) {
          print('⚠️ Error converting candle value: $value - $e');
          return defaultValue;
        }
      }

      final open = safeDouble(row["Open"], 1.0);
      final high = safeDouble(row["High"], 1.0);
      final low = safeDouble(row["Low"], 1.0);
      final close = safeDouble(row["Close"], 1.0);

      // Ensure all values are valid before creating entity
      if (open <= 0 || high <= 0 || low <= 0 || close <= 0) {
        print('⚠️ Skipping invalid candle: O=$open H=$high L=$low C=$close');
        return null;
      }

      return CandleEntity(
        time: dt,
        open: open,
        high: high,
        low: low,
        close: close,
      );
    }).whereType<CandleEntity>().toList();
  }
}
