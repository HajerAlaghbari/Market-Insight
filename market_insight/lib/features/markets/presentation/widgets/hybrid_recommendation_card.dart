import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../api_service.dart';

class HybridRecommendationCard extends ConsumerStatefulWidget {
  final String symbol;
  final String timeframe;
  final int? horizon;
  /// Increments each time a candle closes — triggers a reload.
  final DateTime? lastCandleClose;

  const HybridRecommendationCard({
    super.key,
    required this.symbol,
    this.timeframe = '1h',
    this.horizon,
    this.lastCandleClose,
  });

  @override
  ConsumerState<HybridRecommendationCard> createState() => _HybridRecommendationCardState();
}

class _HybridRecommendationCardState extends ConsumerState<HybridRecommendationCard> {
  Map<String, dynamic>? _recommendation;
  bool _isLoading = true;
  bool _isTranslated = false;
  String? _translatedExplanation;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendation();
  }

  @override
  void didUpdateWidget(HybridRecommendationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload ONLY when timeframe changes OR when a new candle has closed
    final timeframeChanged = oldWidget.timeframe != widget.timeframe;
    final candleClosed = widget.lastCandleClose != null &&
        oldWidget.lastCandleClose != widget.lastCandleClose;
    if (timeframeChanged || candleClosed) {
      _loadRecommendation();
    }
  }

  Future<void> _loadRecommendation() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Small delay so the backend has fresh closed-candle data
    await Future.delayed(const Duration(seconds: 2));

    try {
      final result = await ApiService.getHybridSignal(
        widget.symbol,
        timeframe: widget.timeframe,
        horizon: widget.horizon,
      );
      if (mounted) {
        setState(() {
          _recommendation = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      // On error, just stop the spinner — do NOT retry automatically.
      // A new attempt will be triggered on the next candle close.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleTranslation() async {
    if (_recommendation == null) return;

    if (_isTranslated) {
      setState(() => _isTranslated = false);
      return;
    }

    if (_translatedExplanation != null) {
      setState(() => _isTranslated = true);
      return;
    }

    setState(() => _isTranslating = true);

    try {
      final explanation = _recommendation!['explanation'] as String;
      final translated = await ApiService.translateToArabic(explanation);
      
      if (mounted) {
        setState(() {
          _translatedExplanation = translated;
          _isTranslated = true;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation failed: $e')),
        );
      }
    }
  }

  Color _getSignalColor(String signal) {
    switch (signal.toUpperCase()) {
      case 'BUY':
        return const Color(0xFF10B981);
      case 'SELL':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getSignalIcon(String signal) {
    switch (signal.toUpperCase()) {
      case 'BUY':
        return Icons.trending_up;
      case 'SELL':
        return Icons.trending_down;
      default:
        return Icons.remove;
    }
  }

  Widget _buildStrengthBadge(String strength) {
    final Map<String, Color> colors = {
      'Strong':    const Color(0xFF10B981),
      'Moderate':  const Color(0xFF3B82F6),
      'Weak':      const Color(0xFFF59E0B),
      'Uncertain': const Color(0xFFEF4444),
    };
    final color = colors[strength] ?? const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        strength,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
          ),
        ),
      );
    }

    if (_recommendation == null) {
      return const SizedBox.shrink();
    }

    final signal = _recommendation!['signal'] as String;
    final confidence = (_recommendation!['confidence'] as num).toDouble();
    final dominantSignal = _recommendation!['dominant_signal'] as String? ?? signal;
    final dominantConf = (_recommendation!['dominant_confidence'] as num?)?.toDouble() ?? confidence;
    final isWeakHold = signal == 'HOLD' && dominantSignal != 'HOLD';
    final signalStrength = _recommendation!['signal_strength'] as String? ?? 'Uncertain';
    final isMarketUndecided = _recommendation!['is_market_undecided'] as bool? ?? false;
    final reliabilityScore = (_recommendation!['reliability_score'] as num?)?.toDouble() ?? 0.0;
    final explanation = _isTranslated && _translatedExplanation != null
        ? _translatedExplanation!
        : (_recommendation!['explanation'] as String);
    final probabilities = _recommendation!['probabilities'] as Map<String, dynamic>?;
    
    final tp = _recommendation!['take_profit'] as num?;
    final sl = _recommendation!['stop_loss'] as num?;
    final tech = _recommendation!['technical_features'] as Map<String, dynamic>?;

    final signalColor = _getSignalColor(signal);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A2E),
            signalColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: signalColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: signalColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [signalColor.withOpacity(0.2), signalColor.withOpacity(0.05)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: signalColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: signalColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Hybrid Recommendation',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Builder(builder: (context) {
                        final label = _recommendation?['horizon_label'] as String?;
                        return Text(
                          label != null
                              ? 'Technical + News • $label'
                              : 'Technical + News Analysis',
                          style: TextStyle(
                            fontSize: 10,
                            color: label != null ? const Color(0xFF3B82F6) : Colors.grey[500],
                            fontWeight: label != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                // Translate Button
                IconButton(
                  onPressed: _isTranslating ? null : _toggleTranslation,
                  icon: _isTranslating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        )
                      : Icon(
                          _isTranslated ? Icons.g_translate : Icons.translate,
                          color: _isTranslated ? const Color(0xFF3B82F6) : Colors.white70,
                        ),
                  tooltip: _isTranslated ? 'Show English' : 'Translate to Arabic',
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Signal Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: signalColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: signalColor, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getSignalIcon(signal), color: signalColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            signal.toUpperCase(),
                            style: TextStyle(
                              color: signalColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified, color: signalColor, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${(confidence * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: signalColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Strength badge (only when no lean-SELL/BUY badge to avoid overflow)
                    if (!isWeakHold) ...[
                      const SizedBox(width: 8),
                      _buildStrengthBadge(signalStrength),
                    ],

                    // Lean signal + strength badge (merged)
                    if (isWeakHold) ...
                      [
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getSignalColor(dominantSignal).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getSignalColor(dominantSignal).withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            '$signalStrength ${dominantSignal.toUpperCase()} ${(dominantConf * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: _getSignalColor(dominantSignal),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                  ],
                ),

                // Weak-confidence note
                if (isWeakHold) ...
                  [
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 12, color: Colors.amber[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Low confidence — $dominantSignal tendency but not enough to act',
                          style: TextStyle(color: Colors.amber[600], fontSize: 10),
                        ),
                      ],
                    ),
                  ],

                // Market undecided warning
                if (isMarketUndecided) ...
                  [
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 13, color: Colors.orange[400]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '⚠️ Market Undecided — SELL ≈ BUY probability. Avoid entering now.',
                              style: TextStyle(color: Colors.orange[300], fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                const SizedBox(height: 16),

                // Probabilities Bar
                if (probabilities != null) ...[
                  Row(
                    children: [
                      _buildProbBar('SELL', probabilities['SELL'] ?? 0.0, const Color(0xFFEF4444)),
                      const SizedBox(width: 4),
                      _buildProbBar('HOLD', probabilities['HOLD'] ?? 0.0, const Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      _buildProbBar('BUY', probabilities['BUY'] ?? 0.0, const Color(0xFF10B981)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // TP / SL Zones
                if (tp != null && sl != null && signal != 'HOLD') ...[
                  Row(
                    children: [
                      Expanded(child: _buildTargetCard('Target (TP)', tp.toDouble(), Colors.greenAccent)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTargetCard('Stop Loss (SL)', sl.toDouble(), Colors.redAccent)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Technical Grid
                if (tech != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isTranslated ? 'المؤشرات الفنية الدقيقة' : 'Raw Technical Indicators',
                              style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildTechStat('RSI', (tech['rsi'] as num?)?.toStringAsFixed(1) ?? '--'),
                            _buildTechStat('MACD', (tech['macd'] as num?)?.toStringAsFixed(3) ?? '--'),
                            _buildTechStat('SMA-20', (tech['sma_20'] as num?)?.toStringAsFixed(2) ?? '--'),
                            _buildTechStat('Mom(5)', '${(tech['momentum_5'] as num?)?.toStringAsFixed(2) ?? '--'}%'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Divider
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        signalColor.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Explanation Title
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.amber[300], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _isTranslated ? 'السبب:' : 'Why this recommendation?',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Explanation Text
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(
                    explanation,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: Colors.grey[300],
                      fontFamily: _isTranslated ? 'Arial' : null,
                    ),
                    textDirection: _isTranslated ? TextDirection.rtl : TextDirection.ltr,
                  ),
                ),

                const SizedBox(height: 12),

                // Disclaimer
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange[300], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isTranslated
                              ? 'هذه توصية آلية. استشر خبير مالي قبل اتخاذ قرارات الاستثمار.'
                              : 'AI recommendation. Consult a financial advisor before investing.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange[200],
                          ),
                          textDirection: _isTranslated ? TextDirection.rtl : TextDirection.ltr,
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

  Widget _buildProbBar(String label, double value, Color color) {
    return Expanded(
      flex: (value * 100).round(),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(value * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value.toStringAsFixed(4), style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildTechStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

}
