class NewsEntity {
  final String title;
  final String summary;
  final String sourceUrl;
  final String imageUrl;
  final String publisher;
  final String publishedDate;
  final String symbol;
  final String category;
  final String symbolName;
  final String language;
  final String sentiment;
  final double confidence;
  final double impactScore;
  final Map<String, double> probabilities;

  const NewsEntity({
    required this.title,
    required this.summary,
    required this.sourceUrl,
    required this.imageUrl,
    required this.publisher,
    required this.publishedDate,
    required this.symbol,
    required this.category,
    required this.symbolName,
    required this.language,
    required this.sentiment,
    required this.confidence,
    required this.impactScore,
    required this.probabilities,
  });

  factory NewsEntity.fromJson(Map<String, dynamic> json) {
    final probs = json['probabilities'] as Map<String, dynamic>? ?? {};
    return NewsEntity(
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      sourceUrl: json['source_url'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      publisher: json['publisher'] as String? ?? '',
      publishedDate: json['published_date'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      category: json['category'] as String? ?? '',
      symbolName: json['symbol_name'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      sentiment: json['sentiment'] as String? ?? 'Neutral',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      impactScore: (json['impact_score'] as num?)?.toDouble() ?? 0.5,
      probabilities: {
        'Bearish': (probs['Bearish'] as num?)?.toDouble() ?? 0.33,
        'Neutral': (probs['Neutral'] as num?)?.toDouble() ?? 0.34,
        'Bullish': (probs['Bullish'] as num?)?.toDouble() ?? 0.33,
      },
    );
  }
}

class NewsImpact {
  final String symbol;
  final int articleCount;
  final double avgImpact;
  final String sentimentSummary;
  final int bullishCount;
  final int bearishCount;
  final int neutralCount;

  const NewsImpact({
    required this.symbol,
    required this.articleCount,
    required this.avgImpact,
    required this.sentimentSummary,
    required this.bullishCount,
    required this.bearishCount,
    required this.neutralCount,
  });

  factory NewsImpact.fromJson(Map<String, dynamic> json) {
    return NewsImpact(
      symbol: json['symbol'] as String? ?? '',
      articleCount: json['article_count'] as int? ?? 0,
      avgImpact: (json['avg_impact'] as num?)?.toDouble() ?? 0.5,
      sentimentSummary: json['sentiment_summary'] as String? ?? 'Neutral',
      bullishCount: json['bullish_count'] as int? ?? 0,
      bearishCount: json['bearish_count'] as int? ?? 0,
      neutralCount: json['neutral_count'] as int? ?? 0,
    );
  }
}
