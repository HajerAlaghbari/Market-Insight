import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../api_service.dart';
import '../domain/signal_log_entry.dart';

class SignalLogService {
  static const int _maxEntries = 10;
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static String _uid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');
    return uid;
  }

  static CollectionReference<Map<String, dynamic>> _col() =>
      _db.collection('users').doc(_uid()).collection('signal_log');

  /// Save a new pending signal log entry when a recommendation is generated.
  static Future<String> saveSignal({
    required String symbol,
    required double entryPrice,
    required String recommendation,
    required String timeframe,
    required int horizon,
  }) async {
    final now = DateTime.now();
    final resolutionTime = now.add(
      Duration(seconds: SignalLogEntry.timeframeToSeconds(timeframe) * horizon),
    );

    final entry = SignalLogEntry(
      id: '',
      symbol: symbol,
      recommendationTime: now,
      entryPrice: entryPrice,
      recommendation: recommendation,
      timeframe: timeframe,
      horizon: horizon,
      resolutionTime: resolutionTime,
      status: 'pending',
    );

    final ref = await _col().add(entry.toFirestore());
    await _enforceMaxEntries();
    return ref.id;
  }

  /// Keep only the latest [_maxEntries] — deletes oldest when limit is exceeded.
  static Future<void> _enforceMaxEntries() async {
    final snap = await _col()
        .orderBy('recommendation_time', descending: false)
        .get();
    if (snap.docs.length > _maxEntries) {
      final toDelete = snap.docs.take(snap.docs.length - _maxEntries);
      for (final doc in toDelete) {
        await doc.reference.delete();
      }
    }
  }

  /// Fetch all log entries for the current user, ordered by newest first.
  static Future<List<SignalLogEntry>> fetchAll() async {
    final snap = await _col()
        .orderBy('recommendation_time', descending: true)
        .limit(_maxEntries)
        .get();
    return snap.docs.map(SignalLogEntry.fromFirestore).toList();
  }

  /// Resolve pending entries whose resolution_time has passed.
  /// Fetches actual candle price from backend and updates Firestore.
  static Future<void> resolvePending(List<SignalLogEntry> entries) async {
    final now = DateTime.now();
    final pending = entries.where(
      (e) => e.status == 'pending' && now.isAfter(e.resolutionTime),
    );

    for (final entry in pending) {
      try {
        final actualPrice = await _fetchPriceAtTime(
          entry.symbol,
          entry.timeframe,
          entry.resolutionTime,
        );
        if (actualPrice == null) continue;

        final direction = SignalLogEntry.computeActualDirection(
          entry.entryPrice,
          actualPrice,
        );
        final correct = direction == entry.recommendation;

        await _col().doc(entry.id).update({
          'actual_price': actualPrice,
          'actual_direction': direction,
          'is_correct': correct,
          'status': 'resolved',
        });
      } catch (_) {}
    }
  }

  /// Fetch the close price of the candle closest to [targetTime] from backend.
  /// Falls back to live price if candle data is unavailable.
  static Future<double?> _fetchPriceAtTime(
    String symbol,
    String timeframe,
    DateTime targetTime,
  ) async {
    try {
      final candles = await ApiService.getCandles(
        symbol,
        limit: 200,
        timeframe: timeframe,
      );

      if (candles.isNotEmpty) {
        // Backend returns 'timestamp' (ms) and 'Close' (capitalized)
        Map<String, dynamic>? closest;
        int minDiff = 999999999;

        for (final c in candles) {
          final cMap = c as Map<String, dynamic>;
          final tsRaw = (cMap['timestamp'] as num?)?.toInt() ?? 0;
          if (tsRaw == 0) continue;
          // Binance timestamps are in milliseconds
          final tsMs = tsRaw > 1000000000000 ? tsRaw : tsRaw * 1000;
          final candleTime = DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: true).toLocal();
          final diff = (candleTime.difference(targetTime).inSeconds).abs();
          if (diff < minDiff) {
            minDiff = diff;
            closest = cMap;
          }
        }

        if (closest != null) {
          final closeVal = closest['Close'] ?? closest['close'];
          final price = (closeVal as num?)?.toDouble();
          if (price != null && price > 0) return price;
        }
      }

      // Fallback: use current live price from stream
      return await _fetchLivePrice(symbol);
    } catch (_) {
      return _fetchLivePrice(symbol);
    }
  }

  /// Get current live price as fallback.
  static Future<double?> _fetchLivePrice(String symbol) async {
    try {
      final result = await ApiService.getPrice(symbol);
      return (result['price'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  /// Delete a single log entry.
  static Future<void> delete(String docId) async {
    await _col().doc(docId).delete();
  }

  /// Delete all log entries for the current user.
  static Future<void> clearAll() async {
    final snap = await _col().get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
}
