import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/localization/app_localizations.dart';
import '../data/signal_log_service.dart';
import '../domain/signal_log_entry.dart';

class SignalReviewPage extends StatefulWidget {
  const SignalReviewPage({super.key});

  @override
  State<SignalReviewPage> createState() => _SignalReviewPageState();
}

class _SignalReviewPageState extends State<SignalReviewPage> {
  List<SignalLogEntry> _entries = [];
  bool _loading = true;
  String? _error;
  Timer? _autoResolveTimer;

  bool get _hasPending => _entries.any((e) => e.status == 'pending');

  @override
  void initState() {
    super.initState();
    _load();
    // One-shot retry after 5s (in case backend needs time to warm up)
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _hasPending) _silentResolve();
    });
    // Auto-check every 30 seconds to resolve pending entries
    _autoResolveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _hasPending) _silentResolve();
    });
  }

  @override
  void dispose() {
    _autoResolveTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentResolve() async {
    try {
      await SignalLogService.resolvePending(_entries);
      final updated = await SignalLogService.fetchAll();
      if (mounted) setState(() => _entries = updated);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final entries = await SignalLogService.fetchAll();
      // Resolve any pending entries whose time has passed
      await SignalLogService.resolvePending(entries);
      // Re-fetch after resolution
      final updated = await SignalLogService.fetchAll();
      if (mounted) setState(() { _entries = updated; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  int get _totalResolved => _entries.where((e) => e.status == 'resolved').length;
  int get _correct => _entries.where((e) => e.isCorrect == true).length;
  double get _accuracy => _totalResolved == 0 ? 0 : (_correct / _totalResolved) * 100;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: Text(AppLocalizations.of(context).signalReviewLog, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_loading)
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: AppLocalizations.of(context).clearAll,
            onPressed: _confirmClear,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : Column(
                  children: [
                    _buildSummaryBar(),
                    Expanded(child: _buildTable()),
                  ],
                ),
    );
  }

  Widget _buildSummaryBar() {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statChip(l10n.total, '${_entries.length}', Colors.white),
          _statChip(l10n.resolved, '$_totalResolved', const Color(0xFF3B82F6)),
          _statChip(l10n.correct, '$_correct', const Color(0xFF10B981)),
          _statChip(l10n.accuracy, '${_accuracy.toStringAsFixed(1)}%',
              _accuracy >= 60 ? const Color(0xFF10B981) : _accuracy >= 40 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }

  Widget _buildTable() {
    if (_entries.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 60, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text(l10n.noSignalsYet, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            const SizedBox(height: 6),
            Text(l10n.noSignalsDesc,
                style: TextStyle(color: Colors.grey[700], fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      itemCount: _entries.length,
      itemBuilder: (ctx, i) => _buildEntryCard(_entries[i]),
    );
  }

  Widget _buildEntryCard(SignalLogEntry e) {
    final sigColor = e.recommendation == 'BUY'
        ? const Color(0xFF10B981)
        : e.recommendation == 'SELL'
            ? const Color(0xFFEF4444)
            : Colors.grey;

    final isPending = e.status == 'pending';
    final isCorrect = e.isCorrect;

    Color borderColor = isPending ? Colors.grey.withOpacity(0.3) : (isCorrect == true ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFEF4444).withOpacity(0.4));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: symbol + status badge ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(e.symbol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sigColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sigColor.withOpacity(0.6)),
                  ),
                  child: Text(e.recommendation, style: TextStyle(color: sigColor, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const Spacer(),
                if (isPending)
                  Builder(builder: (ctx) {
                    final l = AppLocalizations.of(ctx);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: Colors.orange.withOpacity(0.5)),
                      ),
                      child: Text(l.pending, style: TextStyle(color: Colors.orange[300], fontSize: 10, fontWeight: FontWeight.w600)),
                    );
                  })
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isCorrect! ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: (isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.6)),
                    ),
                    child: Builder(builder: (ctx) {
                      final l = AppLocalizations.of(ctx);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isCorrect ? Icons.check_circle : Icons.cancel, size: 11, color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                          const SizedBox(width: 4),
                          Text(isCorrect ? l.correct : l.incorrect,
                              style: TextStyle(color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w700)),
                        ],
                      );
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Row 2: data grid ──
            _buildDataGrid(e),
            // ── Row 3: countdown or actual result ──
            const SizedBox(height: 8),
            if (isPending)
              _buildCountdown(e.resolutionTime)
            else
              _buildActualResult(e),
          ],
        ),
      ),
    );
  }

  Widget _buildDataGrid(SignalLogEntry e) {
    final fmt = DateFormat('dd/MM HH:mm');
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _dataCell('Time', fmt.format(e.recommendationTime)),
        _dataCell('Entry Price', '\$${e.entryPrice.toStringAsFixed(2)}'),
        _dataCell('Timeframe', e.timeframe.toUpperCase()),
        _dataCell('Horizon', '${e.horizon} candles'),
        _dataCell('Resolve at', fmt.format(e.resolutionTime)),
        if (e.actualPrice != null) _dataCell('Actual Price', '\$${e.actualPrice!.toStringAsFixed(2)}'),
      ],
    );
  }

  Widget _dataCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 9)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCountdown(DateTime resolutionTime) {
    final l10n = AppLocalizations.of(context);
    final remaining = resolutionTime.difference(DateTime.now());
    final label = remaining.isNegative
        ? l10n.waitingPrice
        : '${l10n.resolvesIn} ${_formatDuration(remaining)}';
    return Row(
      children: [
        Icon(Icons.access_time, size: 12, color: Colors.orange[400]),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: Colors.orange[400], fontSize: 11)),
      ],
    );
  }

  Widget _buildActualResult(SignalLogEntry e) {
    final l10n = AppLocalizations.of(context);
    final dirColor = e.actualDirection == 'BUY'
        ? const Color(0xFF10B981)
        : e.actualDirection == 'SELL'
            ? const Color(0xFFEF4444)
            : Colors.grey;
    final matched = e.recommendation == e.actualDirection;
    return Row(
      children: [
        Text('${l10n.marketMoved} ', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: dirColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: dirColor.withOpacity(0.5)),
          ),
          child: Text(e.actualDirection ?? '-', style: TextStyle(color: dirColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Icon(
          matched ? Icons.check_circle : Icons.cancel,
          size: 14,
          color: matched ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            matched ? l10n.signalMatched : l10n.signalNotMatched,
            style: TextStyle(
              color: matched ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  Future<void> _confirmClear() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(l10n.clearLogs, style: const TextStyle(color: Colors.white)),
        content: Text(l10n.clearAllConfirm, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteAll, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SignalLogService.clearAll();
      _load();
    }
  }
}
