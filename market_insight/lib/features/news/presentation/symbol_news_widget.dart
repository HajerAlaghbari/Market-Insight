import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/news_providers.dart';
import '../domain/news_entity.dart';

/// A reusable widget that shows news articles for a specific symbol.
/// Used inside SymbolDetailsPage in the "News" tab.
class SymbolNewsWidget extends ConsumerWidget {
  final String symbolCode;
  final String symbolName;

  const SymbolNewsWidget({
    super.key,
    required this.symbolCode,
    required this.symbolName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(symbolNewsProvider(symbolCode));
    final impactAsync = ref.watch(newsImpactProvider(symbolCode));

    return Column(
      children: [
        // ── News Impact Summary Card ──
        impactAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (impact) => _NewsImpactCard(impact: impact, symbolName: symbolName),
        ),

        // ── News Articles List ──
        Expanded(
          child: newsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text('Unable to load news', style: TextStyle(color: Colors.grey[400])),
                ],
              ),
            ),
            data: (articles) {
              if (articles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.newspaper, size: 48, color: Colors.grey[700]),
                      const SizedBox(height: 12),
                      Text(
                        'No news for $symbolName',
                        style: TextStyle(color: Colors.grey[400], fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Check back later',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: articles.length,
                itemBuilder: (context, i) => _SymbolNewsCard(article: articles[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  News Impact Summary Card
// ═══════════════════════════════════════════════════════════════════════════════

class _NewsImpactCard extends StatelessWidget {
  final NewsImpact impact;
  final String symbolName;

  const _NewsImpactCard({required this.impact, required this.symbolName});

  @override
  Widget build(BuildContext context) {
    if (impact.articleCount == 0) return const SizedBox.shrink();

    final sentColor = impact.sentimentSummary == 'Bullish'
        ? const Color(0xFF10B981)
        : impact.sentimentSummary == 'Bearish'
            ? const Color(0xFFEF4444)
            : const Color(0xFF6B7280);

    final sentIcon = impact.sentimentSummary == 'Bullish'
        ? Icons.trending_up
        : impact.sentimentSummary == 'Bearish'
            ? Icons.trending_down
            : Icons.remove;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            sentColor.withOpacity(0.08),
            sentColor.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sentColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(sentIcon, color: sentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'News Sentiment',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      impact.sentimentSummary,
                      style: TextStyle(
                        color: sentColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Article count
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${impact.articleCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'articles',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Sentiment distribution bar
          Row(
            children: [
              _SentimentBar(
                label: 'Bullish',
                count: impact.bullishCount,
                total: impact.articleCount,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              _SentimentBar(
                label: 'Neutral',
                count: impact.neutralCount,
                total: impact.articleCount,
                color: const Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              _SentimentBar(
                label: 'Bearish',
                count: impact.bearishCount,
                total: impact.articleCount,
                color: const Color(0xFFEF4444),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Impact score bar
          Row(
            children: [
              Text('Market Impact', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: impact.avgImpact,
                    minHeight: 6,
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(sentColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(impact.avgImpact * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: sentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SentimentBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _SentimentBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;

    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Symbol News Card (compact version for symbol detail page)
// ═══════════════════════════════════════════════════════════════════════════════

class _SymbolNewsCard extends StatelessWidget {
  final NewsEntity article;
  const _SymbolNewsCard({required this.article});

  Color _sentimentColor() {
    switch (article.sentiment) {
      case 'Bullish':
        return const Color(0xFF10B981);
      case 'Bearish':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _sentimentIcon() {
    switch (article.sentiment) {
      case 'Bullish':
        return Icons.trending_up;
      case 'Bearish':
        return Icons.trending_down;
      default:
        return Icons.remove;
    }
  }

  String _timeAgo() {
    try {
      final date = DateTime.parse(article.publishedDate);
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openUrl(article.sourceUrl),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sentiment indicator
                Container(
                  width: 4,
                  height: 50,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: sentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(_sentimentIcon(), color: sentColor, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            article.sentiment,
                            style: TextStyle(
                              color: sentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (article.publisher.isNotEmpty)
                            Expanded(
                              child: Text(
                                article.publisher,
                                style: TextStyle(color: Colors.grey[600], fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Text(
                            _timeAgo(),
                            style: TextStyle(color: Colors.grey[600], fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Image thumbnail
                if (article.imageUrl.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      article.imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
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
