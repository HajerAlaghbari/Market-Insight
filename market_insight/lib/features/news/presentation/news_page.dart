import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/news_providers.dart';
import '../domain/news_entity.dart';

class NewsPage extends ConsumerWidget {
  const NewsPage({super.key});

  static const _categories = [
    (null, 'All', Icons.public),
    ('crypto', 'Crypto', Icons.currency_bitcoin),
    ('stocks', 'Stocks', Icons.candlestick_chart),
    ('fx', 'FX', Icons.swap_horiz),
    ('metals', 'Metals', Icons.savings),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCat = ref.watch(selectedNewsCategoryProvider);
    final newsAsync = ref.watch(newsProvider(selectedCat));

    return Scaffold(
      appBar: AppBar(
        title: const Text("News"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Category Filter Chips ──
          _CategoryFilterBar(
            selected: selectedCat,
            onChanged: (cat) =>
                ref.read(selectedNewsCategoryProvider.notifier).state = cat,
          ),

          // ── News List ──
          Expanded(
            child: newsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('Unable to load news',
                        style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Check backend connection',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              data: (articles) {
                if (articles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.newspaper, size: 64, color: Colors.grey[700]),
                        const SizedBox(height: 16),
                        Text(
                          'No news available yet',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'News will appear once the backend fetches them',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(newsProvider(selectedCat));
                    await Future.delayed(const Duration(seconds: 1));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: articles.length,
                    itemBuilder: (context, i) =>
                        _NewsCard(article: articles[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Category Filter Bar
// ═══════════════════════════════════════════════════════════════════════════════

class _CategoryFilterBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _CategoryFilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: NewsPage._categories.map((cat) {
          final isSelected = selected == cat.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FilterChip(
                selected: isSelected,
                showCheckmark: false,
                avatar: Icon(cat.$3, size: 14,
                    color: isSelected ? Colors.white : Colors.grey[400]),
                label: Text(cat.$2),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[400],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 11,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 0),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: const Color(0xFF1A1A2E),
                selectedColor: const Color(0xFF3B82F6),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF3B82F6)
                      : Colors.grey.withOpacity(0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) => onChanged(cat.$1),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  News Card
// ═══════════════════════════════════════════════════════════════════════════════

class _NewsCard extends StatefulWidget {
  final NewsEntity article;
  const _NewsCard({required this.article});

  @override
  State<_NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<_NewsCard> {
  bool _isTranslated = false;
  String? _translatedTitle;
  String? _translatedSummary;
  bool _isTranslating = false;

  Color _sentimentColor() {
    switch (widget.article.sentiment) {
      case 'Bullish':
        return const Color(0xFF10B981);
      case 'Bearish':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _sentimentIcon() {
    switch (widget.article.sentiment) {
      case 'Bullish':
        return Icons.trending_up;
      case 'Bearish':
        return Icons.trending_down;
      default:
        return Icons.remove;
    }
  }

  String _categoryIcon() {
    switch (widget.article.category) {
      case 'crypto':
        return '₿';
      case 'stocks':
        return '📈';
      case 'fx':
        return '💱';
      case 'metals':
        return '🥇';
      default:
        return '📰';
    }
  }

  String _timeAgo() {
    try {
      final date = DateTime.parse(widget.article.publishedDate);
      final diff = DateTime.now().toUtc().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentColor = _sentimentColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openUrl(widget.article.sourceUrl),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Row: Symbol badge + Time + Sentiment ──
                Row(
                  children: [
                    // Symbol badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFF3B82F6).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_categoryIcon(), style: const TextStyle(fontSize: 10)),
                          const SizedBox(width: 4),
                          Text(
                            widget.article.symbol,
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Publisher
                    if (widget.article.publisher.isNotEmpty)
                      Expanded(
                        child: Text(
                          widget.article.publisher,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    // Time
                    Text(
                      _timeAgo(),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Title + Image ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.article.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.article.imageUrl.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          widget.article.imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A3E),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.image,
                                color: Colors.grey, size: 28),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // ── Summary ──
                if (widget.article.summary.isNotEmpty &&
                    widget.article.summary != widget.article.title) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.article.summary,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),

                // ── Bottom: Sentiment Badge + Impact Bar ──
                Row(
                  children: [
                    // Sentiment badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: sentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sentColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_sentimentIcon(), color: sentColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            widget.article.sentiment,
                            style: TextStyle(
                              color: sentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Confidence
                    Text(
                      '${(widget.article.confidence * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const Spacer(),

                    // Impact mini bar
                    _ImpactMiniBar(impact: widget.article.impactScore),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Impact Mini Bar
// ═══════════════════════════════════════════════════════════════════════════════

class _ImpactMiniBar extends StatelessWidget {
  final double impact;
  const _ImpactMiniBar({required this.impact});

  @override
  Widget build(BuildContext context) {
    final color = impact > 0.65
        ? const Color(0xFF10B981)
        : impact < 0.35
            ? const Color(0xFFEF4444)
            : const Color(0xFF6B7280);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Impact',
          style: TextStyle(color: Colors.grey[600], fontSize: 10),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 50,
          height: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: impact,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}