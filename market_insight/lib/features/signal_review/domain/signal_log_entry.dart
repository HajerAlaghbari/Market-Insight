import 'package:cloud_firestore/cloud_firestore.dart';

class SignalLogEntry {
  final String id;
  final String symbol;
  final DateTime recommendationTime;
  final double entryPrice;
  final String recommendation;
  final String timeframe;
  final int horizon;
  final DateTime resolutionTime;
  final double? actualPrice;
  final String? actualDirection;
  final bool? isCorrect;
  final String status; // 'pending' | 'resolved'

  const SignalLogEntry({
    required this.id,
    required this.symbol,
    required this.recommendationTime,
    required this.entryPrice,
    required this.recommendation,
    required this.timeframe,
    required this.horizon,
    required this.resolutionTime,
    this.actualPrice,
    this.actualDirection,
    this.isCorrect,
    required this.status,
  });

  Map<String, dynamic> toFirestore() => {
        'symbol': symbol,
        'recommendation_time': Timestamp.fromDate(recommendationTime),
        'entry_price': entryPrice,
        'recommendation': recommendation,
        'timeframe': timeframe,
        'horizon': horizon,
        'resolution_time': Timestamp.fromDate(resolutionTime),
        'actual_price': actualPrice,
        'actual_direction': actualDirection,
        'is_correct': isCorrect,
        'status': status,
      };

  factory SignalLogEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SignalLogEntry(
      id: doc.id,
      symbol: d['symbol'] as String,
      recommendationTime: (d['recommendation_time'] as Timestamp).toDate(),
      entryPrice: (d['entry_price'] as num).toDouble(),
      recommendation: d['recommendation'] as String,
      timeframe: d['timeframe'] as String,
      horizon: d['horizon'] as int,
      resolutionTime: (d['resolution_time'] as Timestamp).toDate(),
      actualPrice: (d['actual_price'] as num?)?.toDouble(),
      actualDirection: d['actual_direction'] as String?,
      isCorrect: d['is_correct'] as bool?,
      status: d['status'] as String? ?? 'pending',
    );
  }

  static int timeframeToSeconds(String tf) {
    const map = {
      '1m': 60,
      '5m': 300,
      '15m': 900,
      '30m': 1800,
      '1h': 3600,
      '4h': 14400,
      '1d': 86400,
      '1w': 604800,
      '1M': 2592000,
    };
    return map[tf] ?? 3600;
  }

  static String computeActualDirection(double entryPrice, double actualPrice) {
    if (actualPrice > entryPrice) return 'BUY';
    if (actualPrice < entryPrice) return 'SELL';
    return 'HOLD';
  }
}
