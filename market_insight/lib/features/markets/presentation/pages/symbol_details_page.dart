import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:interactive_chart/interactive_chart.dart';

import '../controllers/providers.dart';
import '../../data/repositories/markets_repo_impl.dart';
import '../../../news/presentation/symbol_news_widget.dart';
import '../../../news/data/news_providers.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../api_service.dart';
import '../../../signal_review/data/signal_log_service.dart';
import '../../../signal_review/domain/signal_log_entry.dart';

enum Timeframe { oneMin, fiveMin, fifteenMin, thirtyMin, oneHour, fourHour, oneDay, oneWeek, oneMonth }

// ─── Safe double helper ─────────────────────────────────────────────
double _safe(double v) {
  if (v.isNaN || v.isInfinite || v <= 0 || v > 1e12) return -1;
  return v;
}

// ─── Build one safe Candle (returns null when data is bad) ──────────
CandleData? _safeCandle(int ts, double o, double h, double l, double c, double vol) {
  if (ts <= 0) return null;

  // Ensure all prices are valid
  if (![o, h, l, c].every((p) => p > 0 && p.isFinite)) return null;

  // Ensure high >= low, open/close within [low, high]
  final hi = [o, h, l, c].reduce(max);
  final lo = [o, h, l, c].reduce(min);

  // volume MUST be > 0
  final safeVol = (_safe(vol) <= 0) ? 1.0 : _safe(vol);

  return CandleData(
    timestamp: ts,
    open: _safe(o),
    high: _safe(hi),
    low: _safe(lo),
    close: _safe(c),
    volume: safeVol,
  );
}

// ─── Error‑safe wrapper that catches RENDER errors ──────────────────
class _ChartErrorBoundary extends StatefulWidget {
  final Widget child;
  const _ChartErrorBoundary({required this.child});

  @override
  State<_ChartErrorBoundary> createState() => _ChartErrorBoundaryState();
}

class _ChartErrorBoundaryState extends State<_ChartErrorBoundary> {
  bool _hasError = false;
  String _error = '';

  @override
  void didUpdateWidget(covariant _ChartErrorBoundary old) {
    super.didUpdateWidget(old);
    if (_hasError) setState(() => _hasError = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Chart loading...', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(_error,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // Catch errors thrown during layout / paint phase
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exceptionAsString();
      if (msg.contains('Infinity') || msg.contains('NaN')) {
        if (mounted) setState(() { _hasError = true; _error = msg; });
      } else {
        originalHandler?.call(details);
      }
    };

    return widget.child;
  }
}

// ════════════════════════════════════════════════════════════════════
//  PAGE
// ════════════════════════════════════════════════════════════════════

class SymbolDetailsPage extends ConsumerStatefulWidget {
  final String code;
  final String name;

  const SymbolDetailsPage({
    super.key,
    required this.code,
    required this.name,
  });

  @override
  ConsumerState<SymbolDetailsPage> createState() => _SymbolDetailsPageState();
}

class _SymbolDetailsPageState extends ConsumerState<SymbolDetailsPage>
    with SingleTickerProviderStateMixin {
  Timeframe _selectedTimeframe = Timeframe.oneHour;
  bool _mounted = true;
  String _currentTimeframeStr = '1h';
  CandleData? _selectedCandle;
  late TabController _tabController;
  // Horizon (number of future candles) — null = use server default
  int? _customHorizon;
  final TextEditingController _horizonController = TextEditingController();

  // Hybrid model retrain state
  bool _hybridRetraining = false;
  Timer? _retrainPollTimer;

  // Prevent duplicate signal log saves
  DateTime? _lastAutoSaveTime;

  // Signal mode: true = auto (on candle close), false = manual
  bool _isAutoSignal = true;
  Map<String, dynamic>? _manualSignalResult;
  bool _isLoadingManualSignal = false;

  // Auto signal: fires only when a candle closes
  Timer? _candleTimer;
  Timer? _countdownTicker;
  Map<String, dynamic>? _autoSignalResult;
  bool _isLoadingAutoSignal = false;
  Duration _timeUntilNextCandle = Duration.zero;
  // Timestamp of the last candle close — passed to HybridRecommendationCard
  DateTime? _lastCandleClose;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentTimeframeStr = _timeframeToString(_selectedTimeframe);
    // Load initial history with default timeframe
    Future.microtask(() async {
      try {
        await ref.read(marketsRepoProvider).startStream(widget.code);
        await ref.read(marketsRepoProvider).loadHistoryWithTimeframe(widget.code, _currentTimeframeStr, horizon: _customHorizon);
      } catch (_) {}
    });
    _startCandleTimer();
  }

  @override
  void dispose() {
    _mounted = false;
    _candleTimer?.cancel();
    _countdownTicker?.cancel();
    _retrainPollTimer?.cancel();
    _tabController.dispose();
    _horizonController.dispose();
    ref.read(marketsRepoProvider).stopStream(widget.code).catchError((_) {});
    super.dispose();
  }

  void _startRetrainPolling() {
    _retrainPollTimer?.cancel();
    _retrainPollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      try {
        final status = await ApiService.getRetrainHybridStatus();
        final s = status['status'] as String? ?? 'idle';
        if (s == 'ready') {
          timer.cancel();
          if (_mounted) { setState(() { _hybridRetraining = false; _autoSignalResult = null; }); _fetchAutoSignal(); }
        } else if (s == 'error' || s == 'idle') {
          timer.cancel();
          if (_mounted) setState(() => _hybridRetraining = false);
        }
      } catch (_) {}
    });
  }

  // ── Candle close timer logic ──────────────────────────────────
  int _timeframeDurationSeconds(String tf) {
    switch (tf) {
      case '1m':  return 60;
      case '5m':  return 5 * 60;
      case '15m': return 15 * 60;
      case '30m': return 30 * 60;
      case '1h':  return 60 * 60;
      case '4h':  return 4 * 60 * 60;
      case '1d':  return 24 * 60 * 60;
      case '1w':  return 7 * 24 * 60 * 60;
      case '1M':  return 30 * 24 * 60 * 60;
      default:    return 60 * 60;
    }
  }

  DateTime _nextCandleCloseUtc(String tf) {
    final now = DateTime.now().toUtc();
    final secs = _timeframeDurationSeconds(tf);

    if (tf == '1M') {
      // Next 1st of month 00:00 UTC
      final next = DateTime.utc(now.year, now.month + 1, 1);
      return next;
    }
    if (tf == '1w') {
      // Next Monday 00:00 UTC
      final daysUntilMon = (DateTime.monday - now.weekday + 7) % 7;
      final d = daysUntilMon == 0 && (now.hour > 0 || now.minute > 0 || now.second > 0) ? 7 : daysUntilMon;
      return DateTime.utc(now.year, now.month, now.day + (d == 0 ? 7 : d));
    }

    // For minute/hour/day: align to epoch grid
    final epochSecs = now.millisecondsSinceEpoch ~/ 1000;
    final nextSlot = ((epochSecs ~/ secs) + 1) * secs;
    return DateTime.fromMillisecondsSinceEpoch(nextSlot * 1000, isUtc: true);
  }

  void _startCandleTimer() {
    _candleTimer?.cancel();
    _countdownTicker?.cancel();

    final closeUtc = _nextCandleCloseUtc(_currentTimeframeStr);
    _timeUntilNextCandle = closeUtc.difference(DateTime.now().toUtc());
    if (_timeUntilNextCandle.isNegative) _timeUntilNextCandle = Duration.zero;

    // Countdown ticker — updates every second
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_mounted) return;
      final remaining = closeUtc.difference(DateTime.now().toUtc());
      if (remaining.isNegative || remaining == Duration.zero) {
        // Candle closed → fetch signal, then schedule next
        _countdownTicker?.cancel();
        _fetchAutoSignal();
        // Restart timer for next candle after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (_mounted && _isAutoSignal) _startCandleTimer();
        });
      } else {
        setState(() => _timeUntilNextCandle = remaining);
      }
    });
  }

  Future<void> _fetchAutoSignal() async {
    if (!_mounted) return;
    final closeTime = DateTime.now();
    setState(() => _isLoadingAutoSignal = true);
    try {
      final result = await ApiService.getHybridSignal(
        widget.code,
        timeframe: _currentTimeframeStr,
      );
      if (_mounted) {
        setState(() {
          _autoSignalResult = result;
          _isLoadingAutoSignal = false;
          _lastCandleClose = closeTime;
        });
        // Save to signal log — only once per candle (avoid duplicates)
        try {
          final tfSecs = SignalLogEntry.timeframeToSeconds(_currentTimeframeStr);
          final now = DateTime.now();
          final tooSoon = _lastAutoSaveTime != null &&
              now.difference(_lastAutoSaveTime!).inSeconds < tfSecs;
          if (!tooSoon) {
            _lastAutoSaveTime = now; // set immediately to block concurrent saves
            final livePrice = ref.read(liveMarketProvider(widget.code)).valueOrNull?['price'];
            final entryPrice = (livePrice as num?)?.toDouble() ?? 0.0;
            if (entryPrice > 0) {
              await SignalLogService.saveSignal(
                symbol: widget.code,
                entryPrice: entryPrice,
                recommendation: (result['signal'] ?? 'HOLD').toString(),
                timeframe: _currentTimeframeStr,
                horizon: _customHorizon ?? 3,
              );
            } else {
              _lastAutoSaveTime = null; // reset if price was invalid
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      if (_mounted) setState(() => _isLoadingAutoSignal = false);
    }
  }

  String _formatCountdown(Duration d) {
    if (d.inDays > 0) {
      final h = d.inHours.remainder(24).toString().padLeft(2, '0');
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '${d.inDays}d ${h}h ${m}m ${s}s';
    }
    if (d.inHours > 0) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '${d.inHours}:${m}:${s}';
    }
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${m}:${s}';
  }

  static const _tfLabels = {
    Timeframe.oneMin: '1m',
    Timeframe.fiveMin: '5m',
    Timeframe.fifteenMin: '15m',
    Timeframe.thirtyMin: '30m',
    Timeframe.oneHour: '1h',
    Timeframe.fourHour: '4h',
    Timeframe.oneDay: '1d',
    Timeframe.oneWeek: '1w',
    Timeframe.oneMonth: '1M',
  };

  String _timeframeToString(Timeframe tf) {
    return _tfLabels[tf]!;
  }

  String _getLocalizedTimeframe(BuildContext context, Timeframe tf) {
    final loc = AppLocalizations.of(context);
    switch (tf) {
      case Timeframe.oneMin:
        return loc.translate('1m');
      case Timeframe.fiveMin:
        return loc.translate('5m');
      case Timeframe.fifteenMin:
        return loc.translate('15m');
      case Timeframe.thirtyMin:
        return loc.translate('30m');
      case Timeframe.oneHour:
        return loc.translate('1h');
      case Timeframe.fourHour:
        return loc.translate('4h');
      case Timeframe.oneDay:
        return loc.translate('1d');
      case Timeframe.oneWeek:
        return loc.translate('1w');
      case Timeframe.oneMonth:
        return loc.translate('1M');
    }
  }

  void _changeTimeframe(Timeframe newTf) async {
    if (_selectedTimeframe == newTf) return;
    
    final newTimeframeStr = _timeframeToString(newTf);
    
    // Load historical data FIRST so backend has the right timeframe data
    try {
      await ref.read(marketsRepoProvider).loadHistoryWithTimeframe(widget.code, newTimeframeStr, horizon: _customHorizon);
    } catch (e) {
      print('Error loading history with timeframe: $e');
    }
    
    // Then update state - this triggers provider rebuild with new timeframe
    if (_mounted) {
      setState(() {
        _selectedTimeframe = newTf;
        _currentTimeframeStr = newTimeframeStr;
        _selectedCandle = null;
        _manualSignalResult = null;
        _autoSignalResult = null;
      });
      _startCandleTimer();
    }
  }

  // ────────────────────────────────────────────────────────────────
  //  DATE FORMATTING
  // ────────────────────────────────────────────────────────────────
  String _formatTimeLabel(int timestamp, int visibleDataCount) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final mon = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    switch (_selectedTimeframe) {
      case Timeframe.oneMin:
      case Timeframe.fiveMin:
        return '$h:$m';
      case Timeframe.fifteenMin:
      case Timeframe.thirtyMin:
        return '$mon/$d $h:$m';
      case Timeframe.oneHour:
      case Timeframe.fourHour:
        return '$mon-$d $h:00';
      case Timeframe.oneDay:
        return '${dt.year}-$mon-$d';
      case Timeframe.oneWeek:
      case Timeframe.oneMonth:
        return '${dt.year}-$mon';
    }
  }

  String _formatCandleDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final mon = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = monthNames[dt.month - 1];
    
    switch (_selectedTimeframe) {
      case Timeframe.oneMin:
      case Timeframe.fiveMin:
        return '$monthName $d, ${dt.year} $h:$m:$s';
      case Timeframe.fifteenMin:
      case Timeframe.thirtyMin:
        return '$monthName $d, ${dt.year} $h:$m';
      case Timeframe.oneHour:
      case Timeframe.fourHour:
        return '$monthName $d, ${dt.year} $h:$m';
      case Timeframe.oneDay:
        return '$monthName $d, ${dt.year}';
      case Timeframe.oneWeek:
      case Timeframe.oneMonth:
        return '$monthName ${dt.year}';
    }
  }

  Map<String, String> _buildOverlayInfo(CandleData candle) {
    final change = (candle.close ?? 0) - (candle.open ?? 0);
    final pct = (candle.open ?? 0) > 0 ? (change / candle.open!) * 100 : 0.0;
    final sign = change >= 0 ? '+' : '';
    final volume = (candle.volume ?? 1.0);
    return {
      'Date': _formatCandleDate(candle.timestamp),
      'Open': (candle.open ?? 0).toStringAsFixed(2),
      'High': (candle.high ?? 0).toStringAsFixed(2),
      'Low': (candle.low ?? 0).toStringAsFixed(2),
      'Close': (candle.close ?? 0).toStringAsFixed(2),
      'Volume': volume.toStringAsFixed(3),
    };
  }

  Widget _buildCandleInfoPanel(CandleData candle) {
    final change = (candle.close ?? 0) - (candle.open ?? 0);
    final pct = (candle.open ?? 0) > 0 ? (change / candle.open!) * 100 : 0.0;
    final isGreen = (candle.close ?? 0) >= (candle.open ?? 0);
    final sign = change >= 0 ? '+' : '';
    final volume = (candle.volume ?? 1.0);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.candlestick_chart, color: Color(0xFF3B82F6), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Candle',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.grey[500], size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatCandleDate(candle.timestamp),
                              style: TextStyle(color: Colors.grey[400], fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Close button
                GestureDetector(
                  onTap: () => setState(() => _selectedCandle = null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, color: Colors.white54, size: 18),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _infoCell('Open', (candle.open ?? 0).toStringAsFixed(2), Colors.white70),
                    _infoCell('High', (candle.high ?? 0).toStringAsFixed(2), const Color(0xFF10B981)),
                    _infoCell('Low', (candle.low ?? 0).toStringAsFixed(2), const Color(0xFFEF4444)),
                    _infoCell('Close', (candle.close ?? 0).toStringAsFixed(2), isGreen ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.show_chart, color: Colors.grey[500], size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Volume: ',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      Text(
                        volume.toStringAsFixed(3),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isGreen
                          ? [const Color(0xFF10B981).withOpacity(0.2), const Color(0xFF10B981).withOpacity(0.1)]
                          : [const Color(0xFFEF4444).withOpacity(0.2), const Color(0xFFEF4444).withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isGreen ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFEF4444).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isGreen ? Icons.trending_up : Icons.trending_down,
                        color: isGreen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$sign${change.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isGreen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($sign${pct.toStringAsFixed(2)}%)',
                        style: TextStyle(
                          color: isGreen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCell(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_mounted) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: AppLocalizations.of(context).signalReview,
            onPressed: () => context.push('/signal-review'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF3B82F6),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[500],
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: [
            Tab(text: AppLocalizations.of(context).overview, icon: const Icon(Icons.candlestick_chart, size: 18)),
            Tab(text: AppLocalizations.of(context).navNews, icon: const Icon(Icons.newspaper, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Overview (Chart + Signal) ──
          _buildOverviewTab(),
          // ── Tab 2: News ──
          SymbolNewsWidget(
            symbolCode: widget.code,
            symbolName: widget.name,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final candlesAsync = ref.watch(candlesProvider((code: widget.code, timeframe: _timeframeToString(_selectedTimeframe))));
    final liveAsync = ref.watch(liveMarketProvider(widget.code));

    return candlesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rawCandles) {
        final chartCandles = rawCandles
            .map((c) => _safeCandle(c.time.millisecondsSinceEpoch, c.open, c.high, c.low, c.close, 1.0))
            .whereType<CandleData>()
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        final display = chartCandles.length > 200
            ? chartCandles.sublist(chartCandles.length - 200)
            : chartCandles;

        if (display.length < 2) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading chart data...'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              // ── Price Header ──
              _buildPriceHeader(liveAsync, display),
              // ── Chart ──
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.40,
                child: _buildChart(display),
              ),
              // ── Timeframe Bar ──
              _buildTimeframeBar(),
              // ── Horizon Input ──
              _buildHorizonInput(),
              // ── Retrain Banner ──
              if (_hybridRetraining) _buildRetrainingBanner(),
              // ── Selected Candle (only when tapped) ──
              if (_selectedCandle != null)
                _buildCandleInfoPanel(_selectedCandle!),
              // ── Signal Mode Toggle + Signal ──
              _buildSignalSection(liveAsync),
              // ── News Sentiment Mini Card ──
              _buildNewsSentimentMini(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  PRICE HEADER
  // ────────────────────────────────────────────────────────────────
  Widget _buildPriceHeader(AsyncValue<Map<String, dynamic>> liveAsync, List<CandleData> display) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: liveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => const Text('--', style: TextStyle(fontSize: 18, color: Colors.white)),
        data: (live) {
          final price = (live['price'] as num?)?.toDouble() ?? 0.0;
          final lastCandle = display.isNotEmpty ? display.last : null;
          final prevPrice = lastCandle?.open ?? price;
          final change = price - prevPrice;
          final pct = prevPrice > 0 ? (change / prevPrice) * 100 : 0.0;
          final isGreen = change >= 0;
          final sign = change >= 0 ? '+' : '';

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    price.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isGreen ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isGreen ? Icons.arrow_upward : Icons.arrow_downward,
                          color: isGreen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$sign${change.toStringAsFixed(2)} ($sign${pct.toStringAsFixed(2)}%)',
                          style: TextStyle(
                            color: isGreen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.3), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(AppLocalizations.of(context).analyze, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  CHART
  // ────────────────────────────────────────────────────────────────
  Widget _buildChart(List<CandleData> display) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: display.length < 3
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading chart data...',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${display.length}/3 candles',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : _ChartErrorBoundary(
                  child: InteractiveChart(
                    candles: display,
                    style: ChartStyle(
                      priceGainColor: const Color(0xFF10B981),
                      priceLossColor: const Color(0xFFEF4444),
                      volumeColor: Colors.grey.withOpacity(0.3),
                      volumeHeightFactor: 0.0,
                      timeLabelHeight: 32,
                      priceLabelWidth: 70,
                    ),
                    timeLabel: _formatTimeLabel,
                    overlayInfo: _buildOverlayInfo,
                    onTap: (candle) {
                      setState(() => _selectedCandle = candle);
                    },
                  ),
                ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  RETRAIN BANNER
  // ────────────────────────────────────────────────────────────────
  Widget _buildRetrainingBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0F3460)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.2), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Retraining Hybrid Model (horizon = $_customHorizon)...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Downloading real market data & training on new horizon. This takes ~1–2 minutes.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  HORIZON INPUT
  // ────────────────────────────────────────────────────────────────
  Widget _buildHorizonInput() {
    final defaultHorizon = {
      '1m': 5, '5m': 6, '15m': 4, '30m': 4,
      '1h': 3, '4h': 3, '1d': 3, '1w': 2, '1M': 2,
    }[_currentTimeframeStr] ?? 3;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.candlestick_chart, color: Color(0xFF3B82F6), size: 18),
          const SizedBox(width: 8),
          Text(
            'Horizon',
            style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Text(
            '(default: $defaultHorizon)',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _horizonController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '$defaultHorizon',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF0F3460),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _applyHorizon(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _applyHorizon,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Apply',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_customHorizon != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                _horizonController.clear();
                setState(() => _customHorizon = null);
                ref.read(marketsRepoProvider)
                    .loadHistoryWithTimeframe(widget.code, _currentTimeframeStr, horizon: null)
                    .catchError((_) {});
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close, color: Color(0xFFEF4444), size: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _applyHorizon() {
    final text = _horizonController.text.trim();
    final parsed = int.tryParse(text);
    if (parsed != null && parsed > 0 && parsed <= 100) {
      setState(() { _customHorizon = parsed; _hybridRetraining = true; });
      ref.read(marketsRepoProvider)
          .loadHistoryWithTimeframe(widget.code, _currentTimeframeStr, horizon: parsed)
          .catchError((_) {});
      ApiService.retrainHybrid(parsed).catchError((_) {
        if (_mounted) setState(() => _hybridRetraining = false);
      });
      _startRetrainPolling();
      FocusScope.of(context).unfocus();
    } else if (text.isEmpty) {
      setState(() => _customHorizon = null);
      ref.read(marketsRepoProvider)
          .loadHistoryWithTimeframe(widget.code, _currentTimeframeStr, horizon: null)
          .catchError((_) {});
      FocusScope.of(context).unfocus();
    }
  }

  // ────────────────────────────────────────────────────────────────
  //  TIMEFRAME BAR
  // ────────────────────────────────────────────────────────────────
  Widget _buildTimeframeBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: Timeframe.values.map((tf) {
          final sel = _selectedTimeframe == tf;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_mounted) _changeTimeframe(tf);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: sel
                      ? const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)])
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getLocalizedTimeframe(context, tf),
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.grey[500],
                    fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  SIGNAL SECTION (Auto / Manual toggle)
  // ────────────────────────────────────────────────────────────────
  Future<void> _generateManualSignal() async {
    if (_isLoadingManualSignal) return;
    setState(() => _isLoadingManualSignal = true);
    try {
      final result = await ApiService.getHybridSignal(
        widget.code,
        timeframe: _currentTimeframeStr,
      );
      if (_mounted) {
        setState(() {
          _manualSignalResult = result;
          _isLoadingManualSignal = false;
        });
        // Save to signal log
        try {
          final livePrice = ref.read(liveMarketProvider(widget.code)).valueOrNull?['price'];
          final entryPrice = (livePrice as num?)?.toDouble() ?? 0.0;
          if (entryPrice > 0) {
            await SignalLogService.saveSignal(
              symbol: widget.code,
              entryPrice: entryPrice,
              recommendation: (result['signal'] ?? 'HOLD').toString(),
              timeframe: _currentTimeframeStr,
              horizon: _customHorizon ?? 3,
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      if (_mounted) {
        setState(() => _isLoadingManualSignal = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _buildSignalSection(AsyncValue<Map<String, dynamic>> liveAsync) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // ── Toggle Bar ──
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (!_isAutoSignal) setState(() => _isAutoSignal = true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: _isAutoSignal
                            ? const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)])
                            : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.autorenew,
                            size: 16,
                            color: _isAutoSignal ? Colors.white : Colors.grey[500],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context).translate('auto_signal'),
                            style: TextStyle(
                              color: _isAutoSignal ? Colors.white : Colors.grey[500],
                              fontWeight: _isAutoSignal ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_isAutoSignal) setState(() => _isAutoSignal = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: !_isAutoSignal
                            ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                            : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 16,
                            color: !_isAutoSignal ? Colors.white : Colors.grey[500],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context).translate('manual_signal'),
                            style: TextStyle(
                              color: !_isAutoSignal ? Colors.white : Colors.grey[500],
                              fontWeight: !_isAutoSignal ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Content based on mode ──
          if (_isAutoSignal)
            _buildAutoSignalContent(liveAsync)
          else
            _buildManualSignalContent(),
        ],
      ),
    );
  }

  Widget _buildAutoSignalContent(AsyncValue<Map<String, dynamic>> liveAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          // ── Countdown to next candle close ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).translate('next_candle_close'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatCountdown(_timeUntilNextCandle),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '($_currentTimeframeStr)',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // ── Loading indicator ──
          if (_isLoadingAutoSignal)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6))),
            ),
          // ── Signal result (shown after candle closes) ──
          if (_autoSignalResult != null && !_isLoadingAutoSignal)
            _buildAutoResultCard(),
          // ── Waiting message (no signal yet) ──
          if (_autoSignalResult == null && !_isLoadingAutoSignal)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Icon(Icons.hourglass_top, size: 28, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).translate('waiting_candle_close'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _signalColor(String s) => s == 'BUY' ? const Color(0xFF10B981) : s == 'SELL' ? const Color(0xFFEF4444) : Colors.grey;

  Widget _buildStrengthBadge(String strength) {
    final Map<String, Color> colors = {
      'Strong':    const Color(0xFF10B981),
      'Moderate':  const Color(0xFF3B82F6),
      'Weak':      const Color(0xFFF59E0B),
      'Uncertain': const Color(0xFFEF4444),
    };
    final color = colors[strength] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(strength, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildAutoResultCard() {
    final sig = (_autoSignalResult!['signal'] ?? 'HOLD').toString();
    if (sig == 'BUY' || sig == 'SELL') return _buildTradingCard(_autoSignalResult!, isAuto: true);
    final confidence = ((_autoSignalResult!['confidence'] as num?)?.toDouble() ?? 0.0);
    final explanation = _autoSignalResult!['explanation'] as String? ?? '';
    final probabilities = _autoSignalResult!['probabilities'] as Map<String, dynamic>?;
    final dominantSignal = (_autoSignalResult!['dominant_signal'] ?? sig).toString();
    final dominantConf = ((_autoSignalResult!['dominant_confidence'] as num?)?.toDouble() ?? confidence);
    final signalStrength = (_autoSignalResult!['signal_strength'] ?? 'Uncertain').toString();
    final isWeakHold = sig == 'HOLD' && dominantSignal != 'HOLD';
    final isMarketUndecided = _autoSignalResult!['is_market_undecided'] as bool? ?? false;
    final clr = _signalColor(sig);
    final icon = sig == 'BUY'
        ? Icons.trending_up
        : sig == 'SELL'
            ? Icons.trending_down
            : Icons.remove;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [clr.withOpacity(0.12), clr.withOpacity(0.04)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: clr.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: clr.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: clr, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: clr, size: 18),
                    const SizedBox(width: 6),
                    Text(sig, style: TextStyle(color: clr, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: clr, size: 14),
                    const SizedBox(width: 4),
                    Text('${(confidence * 100).toStringAsFixed(0)}%', style: TextStyle(color: clr, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 4),
                    Text('AUTO', style: TextStyle(color: const Color(0xFF3B82F6), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (isWeakHold)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: _signalColor(dominantSignal).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: _signalColor(dominantSignal).withOpacity(0.5)),
                  ),
                  child: Text('$signalStrength ${dominantSignal.toUpperCase()} ${(dominantConf * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: _signalColor(dominantSignal), fontSize: 10, fontWeight: FontWeight.w700)),
                )
              else
                _buildStrengthBadge(signalStrength),
              if (isWeakHold) ...[const SizedBox(width: 6), Expanded(child: Text('Low confidence — $dominantSignal tendency', style: TextStyle(color: Colors.amber[600], fontSize: 10)))],
            ],
          ),
          if (isMarketUndecided) ...[const SizedBox(height: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(7), border: Border.all(color: Colors.orange.withOpacity(0.4))), child: Row(children: [Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange[400]), const SizedBox(width: 5), Expanded(child: Text('⚠️ Market Undecided — SELL ≈ BUY. Avoid entering now.', style: TextStyle(color: Colors.orange[300], fontSize: 10)))]))],
          if (probabilities != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _buildMiniProbBar('SELL', (probabilities['SELL'] as num?)?.toDouble() ?? 0.0, const Color(0xFFEF4444)),
                const SizedBox(width: 4),
                _buildMiniProbBar('HOLD', (probabilities['HOLD'] as num?)?.toDouble() ?? 0.0, Colors.grey),
                const SizedBox(width: 4),
                _buildMiniProbBar('BUY', (probabilities['BUY'] as num?)?.toDouble() ?? 0.0, const Color(0xFF10B981)),
              ],
            ),
          ],
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber[300]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(explanation, style: TextStyle(fontSize: 11, color: Colors.grey[400], height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualSignalContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          // Generate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoadingManualSignal ? null : _generateManualSignal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              child: _isLoadingManualSignal
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.psychology, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${AppLocalizations.of(context).translate('generate_signal')} ($_currentTimeframeStr)',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          // Result card
          if (_manualSignalResult != null) _buildManualResultCard(),
          if (_manualSignalResult == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).translate('tap_to_generate'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildManualResultCard() {
    final sig = (_manualSignalResult!['signal'] ?? 'HOLD').toString();
    if (sig == 'BUY' || sig == 'SELL') return _buildTradingCard(_manualSignalResult!, isAuto: false);
    final confidence = ((_manualSignalResult!['confidence'] as num?)?.toDouble() ?? 0.0);
    final explanation = _manualSignalResult!['explanation'] as String? ?? '';
    final probabilities = _manualSignalResult!['probabilities'] as Map<String, dynamic>?;
    final dominantSignal = (_manualSignalResult!['dominant_signal'] ?? sig).toString();
    final dominantConf = ((_manualSignalResult!['dominant_confidence'] as num?)?.toDouble() ?? confidence);
    final signalStrength = (_manualSignalResult!['signal_strength'] ?? 'Uncertain').toString();
    final isWeakHold = sig == 'HOLD' && dominantSignal != 'HOLD';
    final isMarketUndecided = _manualSignalResult!['is_market_undecided'] as bool? ?? false;
    final clr = _signalColor(sig);
    final icon = sig == 'BUY'
        ? Icons.trending_up
        : sig == 'SELL'
            ? Icons.trending_down
            : Icons.remove;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [clr.withOpacity(0.12), clr.withOpacity(0.04)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: clr.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Signal + confidence
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: clr.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: clr, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: clr, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      sig,
                      style: TextStyle(color: clr, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: clr, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${(confidence * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: clr, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _currentTimeframeStr.toUpperCase(),
                style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (isWeakHold)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: _signalColor(dominantSignal).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: _signalColor(dominantSignal).withOpacity(0.5)),
                  ),
                  child: Text('$signalStrength ${dominantSignal.toUpperCase()} ${(dominantConf * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: _signalColor(dominantSignal), fontSize: 10, fontWeight: FontWeight.w700)),
                )
              else
                _buildStrengthBadge(signalStrength),
              if (isWeakHold) ...[const SizedBox(width: 6), Expanded(child: Text('Low confidence — $dominantSignal tendency', style: TextStyle(color: Colors.amber[600], fontSize: 10)))],
            ],
          ),
          if (isMarketUndecided) ...[const SizedBox(height: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(7), border: Border.all(color: Colors.orange.withOpacity(0.4))), child: Row(children: [Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange[400]), const SizedBox(width: 5), Expanded(child: Text('⚠️ Market Undecided — SELL ≈ BUY. Avoid entering now.', style: TextStyle(color: Colors.orange[300], fontSize: 10)))]))],
          // Probability bars
          if (probabilities != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _buildMiniProbBar('SELL', (probabilities['SELL'] as num?)?.toDouble() ?? 0.0, const Color(0xFFEF4444)),
                const SizedBox(width: 4),
                _buildMiniProbBar('HOLD', (probabilities['HOLD'] as num?)?.toDouble() ?? 0.0, Colors.grey),
                const SizedBox(width: 4),
                _buildMiniProbBar('BUY', (probabilities['BUY'] as num?)?.toDouble() ?? 0.0, const Color(0xFF10B981)),
              ],
            ),
          ],
          // Explanation
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber[300]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      explanation,
                      style: TextStyle(fontSize: 11, color: Colors.grey[400], height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  TRADING CARD — BUY / SELL only
  // ────────────────────────────────────────────────────────────────
  int _priceDecimals(double price) {
    if (price <= 0) return 2;
    if (price < 0.01) return 6;
    if (price < 1) return 5;
    if (price < 10) return 4;
    return 2;
  }

  Widget _buildTradingCard(Map<String, dynamic> result, {required bool isAuto}) {
    final sig = (result['signal'] ?? 'BUY').toString();
    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
    final probabilities = result['probabilities'] as Map<String, dynamic>?;
    final signalStrength = (result['signal_strength'] ?? 'Uncertain').toString();
    final techFeatures = result['technical_features'] as Map<String, dynamic>?;
    final isMarketUndecided = result['is_market_undecided'] as bool? ?? false;

    final horizon = (result['horizon'] as num?)?.toInt() ?? 14;
    final entryPrice = (techFeatures?['current_price'] as num?)?.toDouble() ?? 0.0;
    final stopLoss = (result['stop_loss'] as num?)?.toDouble();

    final isBuy = sig == 'BUY';
    final clr = _signalColor(sig);
    final icon = isBuy ? Icons.trending_up : Icons.trending_down;
    final dec = _priceDecimals(entryPrice);

    double? tp1, tp2, tp3;
    if (entryPrice > 0 && stopLoss != null && stopLoss > 0) {
      final risk = (entryPrice - stopLoss).abs();
      tp1 = isBuy ? entryPrice + 1.75 * risk : entryPrice - 1.75 * risk;
      tp2 = isBuy ? entryPrice + 3.5 * risk  : entryPrice - 3.5 * risk;
      tp3 = isBuy ? entryPrice + 6.125 * risk : entryPrice - 6.125 * risk;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: clr.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Signal | Confidence | Timeframe ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: clr.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: clr, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: clr, size: 20),
                    const SizedBox(width: 8),
                    Text(sig,
                        style: TextStyle(
                            color: clr,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.verified, color: clr, size: 14),
                  const SizedBox(width: 4),
                  Text('${(confidence * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                          color: clr, fontSize: 14, fontWeight: FontWeight.bold)),
                ]),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_currentTimeframeStr.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Row 2: Strength + AUTO badge ──
          Row(children: [
            _buildStrengthBadge(signalStrength),
            if (isAuto) ...[  
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.auto_awesome, size: 10, color: Color(0xFF3B82F6)),
                  SizedBox(width: 3),
                  Text('AUTO',
                      style: TextStyle(
                          color: Color(0xFF3B82F6),
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          // ── Row 3: Probability bars ──
          if (probabilities != null)
            Row(children: [
              _buildMiniProbBar('SELL',
                  (probabilities['SELL'] as num?)?.toDouble() ?? 0.0,
                  const Color(0xFFEF4444)),
              const SizedBox(width: 4),
              _buildMiniProbBar('HOLD',
                  (probabilities['HOLD'] as num?)?.toDouble() ?? 0.0,
                  Colors.grey),
              const SizedBox(width: 4),
              _buildMiniProbBar('BUY',
                  (probabilities['BUY'] as num?)?.toDouble() ?? 0.0,
                  const Color(0xFF10B981)),
            ]),
          if (isMarketUndecided) ...[  
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange[400]),
                const SizedBox(width: 5),
                Expanded(
                    child: Text('⚠️ Market Undecided — SELL ≈ BUY.',
                        style: TextStyle(color: Colors.orange[300], fontSize: 10))),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          const SizedBox(height: 14),
          // ── Entry Price ──
          if (entryPrice > 0) ...[  
            _buildTradeRow(
              price: entryPrice,
              decimals: dec,
              priceColor: clr,
              rightLabel: isBuy ? 'شراء لميت' : 'بيع لميت',
              subLabel: 'سعر الدخول',
              isEntry: true,
              actionColor: clr,
            ),
            const SizedBox(height: 8),
            // ── Horizon hint ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(Icons.schedule, size: 13, color: Colors.amber[400]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'الأهداف متوقعة خلال $horizon شمعة على إطار ${_currentTimeframeStr.toUpperCase()}',
                    style: TextStyle(color: Colors.amber[300], fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          // ── SL ──
          if (stopLoss != null && stopLoss > 0) ...[  
            _buildTradeRow(
              price: stopLoss,
              decimals: dec,
              priceColor: const Color(0xFFEF4444),
              rightLabel: 'SL',
              subLabel: 'وقف الخسارة',
              trailingIcon: Icons.shield_outlined,
              trailingIconColor: const Color(0xFFEF4444),
            ),
            const SizedBox(height: 8),
          ],
          // ── TP1 ──
          if (tp1 != null) ...[  
            _buildTradeRow(
              price: tp1,
              decimals: dec,
              priceColor: const Color(0xFF10B981),
              rightLabel: 'TP1',
              subLabel: 'الهدف الأول',
              trailingIcon: Icons.flag_outlined,
              trailingIconColor: const Color(0xFF10B981),
            ),
            const SizedBox(height: 8),
          ],
          // ── TP2 ──
          if (tp2 != null) ...[  
            _buildTradeRow(
              price: tp2,
              decimals: dec,
              priceColor: const Color(0xFF10B981),
              rightLabel: 'TP2',
              subLabel: 'الهدف الثاني',
              trailingIcon: Icons.flag_outlined,
              trailingIconColor: const Color(0xFF10B981),
            ),
            const SizedBox(height: 8),
          ],
          // ── TP3 ──
          if (tp3 != null) ...[  
            _buildTradeRow(
              price: tp3,
              decimals: dec,
              priceColor: const Color(0xFF10B981),
              rightLabel: 'TP3',
              subLabel: 'الهدف الثالث',
              trailingIcon: Icons.flag_outlined,
              trailingIconColor: const Color(0xFF10B981),
            ),
            const SizedBox(height: 8),
          ],
          // ── TP OPEN ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('∞',
                  style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              Row(children: [
                Text('هدف مفتوح',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                const SizedBox(width: 8),
                const Icon(Icons.all_inclusive, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 4),
                Text('TP OPEN',
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ]),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.07), height: 1),
          const SizedBox(height: 12),
          // ── Arabic description ──
          _buildTradingDescription(
            sig: sig,
            confidence: confidence,
            strength: signalStrength,
            horizon: horizon,
            entryPrice: entryPrice,
            stopLoss: stopLoss,
            tp1: tp1,
          ),
        ],
      ),
    );
  }

  Widget _buildTradingDescription({
    required String sig,
    required double confidence,
    required String strength,
    required int horizon,
    required double entryPrice,
    required double? stopLoss,
    required double? tp1,
  }) {
    final isBuy = sig == 'BUY';
    final action   = isBuy ? 'الشراء' : 'البيع';
    final direction = isBuy ? 'صاعد' : 'هابط';
    final confPct  = (confidence * 100).toStringAsFixed(0);

    String strengthAr;
    switch (strength) {
      case 'Strong':   strengthAr = 'قوية';       break;
      case 'Moderate': strengthAr = 'متوسطة';     break;
      case 'Weak':     strengthAr = 'ضعيفة';      break;
      default:         strengthAr = 'غير محددة';
    }

    String rrText = '';
    if (entryPrice > 0 && stopLoss != null && stopLoss > 0 && tp1 != null) {
      final risk   = (entryPrice - stopLoss).abs();
      final reward = (tp1 - entryPrice).abs();
      if (risk > 0) {
        final rr = reward / risk;
        rrText = '، ونسبة المكافأة للمخاطرة ${rr.toStringAsFixed(1)}:1 للهدف الأول';
      }
    }

    final h1 = (horizon * 0.5).ceil();
    final h2 = horizon;
    final h3 = horizon * 2;

    final desc =
        'توجه السوق $direction بثقة $confPct% وإشارة $strengthAr وفق النموذج الهجين. '
        'يُنصح بالدخول بـ$action عند السعر المحدد مع الالتزام بوقف الخسارة لحماية رأس المال$rrText. '
        'الهدف الأول (TP1) متوقع خلال ~$h1 شمعة، والثاني (TP2) خلال ~$h2 شمعة، '
        'أما الثالث (TP3) فهو هدف ممتد يتجاوز $h3 شمعة للمدى الأبعد.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15, color: Colors.amber[400]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.55),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeRow({
    required double price,
    required int decimals,
    required Color priceColor,
    required String rightLabel,
    required String subLabel,
    bool isEntry = false,
    Color actionColor = const Color(0xFF10B981),
    IconData? trailingIcon,
    Color trailingIconColor = const Color(0xFF10B981),
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          price.toStringAsFixed(decimals),
          style: TextStyle(
            color: priceColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subLabel,
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            const SizedBox(width: 8),
            if (isEntry)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: actionColor, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                  color: actionColor.withOpacity(0.08),
                ),
                child: Text(rightLabel,
                    style: TextStyle(
                        color: actionColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              )
            else ...[  
              Text(rightLabel,
                  style: TextStyle(
                      color: trailingIconColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              if (trailingIcon != null)
                Icon(trailingIcon, color: trailingIconColor, size: 16),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMiniProbBar(String label, double value, Color color) {
    final pct = (value * 100).clamp(0, 100);
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w600)),
              Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[800],
              color: color,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  NEWS SENTIMENT MINI CARD
  // ────────────────────────────────────────────────────────────────
  Widget _buildNewsSentimentMini() {
    final impactAsync = ref.watch(newsImpactProvider(widget.code));

    return impactAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (impact) {
        if (impact.articleCount == 0) return const SizedBox.shrink();

        final sentColor = impact.sentimentSummary == 'Bullish'
            ? const Color(0xFF10B981)
            : impact.sentimentSummary == 'Bearish'
                ? const Color(0xFFEF4444)
                : Colors.grey;

        final sentIcon = impact.sentimentSummary == 'Bullish'
            ? Icons.trending_up
            : impact.sentimentSummary == 'Bearish'
                ? Icons.trending_down
                : Icons.remove;

        return GestureDetector(
          onTap: () {
            _tabController.animateTo(1);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sentColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.newspaper, color: sentColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'News Sentiment',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(sentIcon, color: sentColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            impact.sentimentSummary,
                            style: TextStyle(
                              color: sentColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${impact.articleCount} articles',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Impact score
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(impact.avgImpact * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: sentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'impact',
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey[600], size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}