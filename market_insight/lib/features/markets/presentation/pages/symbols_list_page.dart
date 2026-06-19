import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/symbol.dart';
import '../controllers/providers.dart';

import '../../../favorites/presentation/controllers/favorites_providers.dart';
import '../../../../app/localization/app_localizations.dart';

class SymbolsListPage extends ConsumerWidget {
  final MarketCategory category;
  const SymbolsListPage({super.key, required this.category});

  String getTitle(BuildContext context) => switch (category) {
    MarketCategory.crypto => AppLocalizations.of(context).navCrypto,
    MarketCategory.metals => AppLocalizations.of(context).navMetals,
    MarketCategory.fx => AppLocalizations.of(context).navFx,
    MarketCategory.stocks => AppLocalizations.of(context).navStocks,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(symbolsProvider(category));
    final favAsync = ref.watch(favoriteCodesProvider);

    final favCodes = favAsync.value ?? <String>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(getTitle(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final s = items[i];
            final isFav = favCodes.contains(s.code);

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () =>
                  context.push('/symbol/${s.code}', extra: {'name': s.name}),
              child: Card(
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70)),
                            const SizedBox(height: 6),
                            Text(
                              s.code,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('dd. HH:mm:ss')
                                  .format(DateTime.now()),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),

                      /// ⭐ FAVORITE BUTTON
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          color: isFav ? Colors.amber : Colors.white54,
                        ),
                        onPressed: () {
                          ref.read(toggleFavoriteProvider)(code: s.code, name: s.name);
                        },
                      ),

                      const SizedBox(width: 6),

                      _BidAsk(
                        bid: s.bid,
                        ask: s.ask,
                        isUp: s.isUp,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SignalBadge extends StatelessWidget {
  final String signal;
  const _SignalBadge({required this.signal});

  @override
  Widget build(BuildContext context) {
    final color = signal == "BUY"
        ? Colors.green
        : signal == "SELL"
        ? Colors.red
        : Colors.grey;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        signal,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _BidAsk extends StatefulWidget {
  final double bid;
  final double ask;
  final bool isUp;

  const _BidAsk({
    required this.bid,
    required this.ask,
    required this.isUp,
  });

  @override
  State<_BidAsk> createState() => _BidAskState();
}

class _BidAskState extends State<_BidAsk> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;
  double? _previousBid;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _updateColorAnimation();
  }

  @override
  void didUpdateWidget(_BidAsk oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bid != widget.bid) {
      _previousBid = oldWidget.bid;
      _updateColorAnimation();
      _controller.forward(from: 0);
    }
  }

  void _updateColorAnimation() {
    final targetColor = widget.isUp ? Colors.greenAccent : Colors.redAccent;
    _colorAnimation = ColorTween(
      begin: targetColor.withOpacity(0.5),
      end: targetColor,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    if (v < 10) return v.toStringAsFixed(5);
    if (v < 1000) return v.toStringAsFixed(2);
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(AppLocalizations.of(context).bid, style: const TextStyle(fontSize: 12, color: Colors.white54)),
            Text(
              _fmt(widget.bid),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _colorAnimation.value ?? (widget.isUp ? Colors.greenAccent : Colors.redAccent),
              ),
            ),
            const SizedBox(height: 10),
            Text(AppLocalizations.of(context).ask, style: const TextStyle(fontSize: 12, color: Colors.white54)),
            Text(
              _fmt(widget.ask),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ],
        );
      },
    );
  }
}