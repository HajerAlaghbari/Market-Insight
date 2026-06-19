import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const List<String> _baseUrls = [
    // For local development:
    "http://10.0.2.2:8000",
    "http://192.168.0.181:8000",
    
    // For production (after deploying to cloud):
    // "https://YOUR-APP-NAME.onrender.com",
  ];
  static String? _activeBaseUrl;

  static String toBackendSymbol(String code) {
    final normalized = code.trim().toUpperCase();
    const directMap = {
      "BTCUSD": "BTC/USDT",
      "ETHUSD": "ETH/USDT",
      "BNBUSD": "BNB/USDT",
      "XAUUSD": "XAUUSD",
      "XAGUSD": "XAGUSD",
      "XPTUSD": "XPTUSD",
      "EURUSD": "EURUSD",
      "GBPUSD": "GBPUSD",
      "EURGBP": "EURGBP",
      "AAPL": "AAPL",
      "AMZN": "AMZN",
      "TSLA": "TSLA",
    };

    if (normalized.contains('/')) {
      return normalized;
    }

    if (directMap.containsKey(normalized)) {
      return directMap[normalized]!;
    }

    if (normalized.endsWith("USD") && normalized.length > 3) {
      final base = normalized.substring(0, normalized.length - 3);
      return "$base/USDT";
    }

    return normalized;
  }

  static Future<Map<String, dynamic>> startStream(String symbolCode) async {
    final symbol = toBackendSymbol(symbolCode);
    final res = await _requestWithFallback(
      (base) => http.post(
        Uri.parse("$base/start-stream"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"symbol": symbol}),
      ),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> loadHistory(String symbolCode) async {
    final symbol = toBackendSymbol(symbolCode);
    final res = await _requestWithFallback(
      (base) => http.post(
        Uri.parse("$base/load-history"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"symbol": symbol}),
      ),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> loadHistoryWithTimeframe(String symbolCode, String timeframe, {int? horizon}) async {
    final symbol = toBackendSymbol(symbolCode);
    final body = <String, dynamic>{"symbol": symbol, "timeframe": timeframe};
    if (horizon != null) body["horizon"] = horizon;
    final res = await _requestWithFallback(
      (base) => http.post(
        Uri.parse("$base/load-history-timeframe"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> stopStream(String symbolCode) async {
    final symbol = toBackendSymbol(symbolCode);
    try {
      final res = await _requestWithFallback(
        (base) => http.post(
          Uri.parse("$base/stop-stream"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"symbol": symbol}),
        ),
      );
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {"error": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getPrice(String symbolCode) async {
    final symbol = Uri.encodeComponent(toBackendSymbol(symbolCode));
    final res = await _requestWithFallback(
      (base) => http.get(Uri.parse("$base/price/$symbol")),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getSignal(String symbolCode) async {
    final symbol = Uri.encodeComponent(toBackendSymbol(symbolCode));
    final res = await _requestWithFallback(
      (base) => http.get(Uri.parse("$base/signal/$symbol")),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getCandles(String symbolCode, {int limit = 200, String timeframe = '1h'}) async {
    final symbol = Uri.encodeComponent(toBackendSymbol(symbolCode));
    final res = await _requestWithFallback(
      (base) => http.get(Uri.parse("$base/candles/$symbol?limit=$limit&timeframe=$timeframe")),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final candles = data["candles"];
    if (candles is List) {
      return candles;
    }
    return const [];
  }

  // ─── News Endpoints ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> getNews({String? category, String? symbol, int limit = 50}) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (symbol != null) params['symbol'] = symbol;
    params['limit'] = limit.toString();
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');

    final res = await _requestWithFallback(
      (base) => http.get(Uri.parse("$base/news?$query")),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getNewsForSymbol(String symbolCode, {int limit = 20}) async {
    final symbol = Uri.encodeComponent(_toNewsSymbol(symbolCode));
    final res = await _requestWithFallback(
      (base) => http.get(Uri.parse("$base/news/symbol/$symbol?limit=$limit")),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getNewsImpact(String symbolCode) async {
    final symbol = Uri.encodeComponent(_toNewsSymbol(symbolCode));
    final res = await _requestWithFallback(
      (base) => http.get(Uri.parse("$base/news/impact/$symbol")),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Convert Flutter symbol codes to news-service format (BTCUSD, AAPL, etc.)
  static String _toNewsSymbol(String code) {
    final normalized = code.trim().toUpperCase();
    // News service uses BTCUSD format, not BTC/USDT
    const newsMap = {
      "BTC/USDT": "BTCUSD",
      "ETH/USDT": "ETHUSD",
      "BNB/USDT": "BNBUSD",
    };
    return newsMap[normalized] ?? normalized;
  }

  static Future<Map<String, dynamic>> getNewsCategories() async {
    final res = await _requestWithFallback(
      (base) => http.get(Uri.parse("$base/news/categories")),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─── Hybrid Signal Endpoint ───────────────────────────────────────
  
  static Future<Map<String, dynamic>> getHybridSignal(String symbolCode, {String timeframe = '1h', int? horizon}) async {
    final symbol = Uri.encodeComponent(toBackendSymbol(symbolCode));
    var url = "$_activeBaseUrl/signal-hybrid?symbol=$symbol&timeframe=$timeframe";
    if (horizon != null) url += "&horizon=$horizon";
    final res = await _requestWithFallback(
      (base) {
        var u = "$base/signal-hybrid?symbol=$symbol&timeframe=$timeframe";
        if (horizon != null) u += "&horizon=$horizon";
        return http.get(Uri.parse(u));
      },
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─── Hybrid Retrain Endpoints ─────────────────────────────────────

  static Future<Map<String, dynamic>> retrainHybrid(int horizon) async {
    final res = await _requestWithFallback(
      (base) => http.post(Uri.parse("$base/retrain-hybrid?horizon=$horizon")),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getRetrainHybridStatus() async {
    final res = await _requestWithFallback(
      (base) => http.get(Uri.parse("$base/retrain-hybrid/status")),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─── Translation (Simple Google Translate API alternative) ────────
  
  static Future<String> translateToArabic(String text) async {
    // Using a simple translation approach - you can replace with Google Translate API
    // For now, we'll use a basic translation service or return a placeholder
    try {
      final res = await http.post(
        Uri.parse("https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=ar&dt=t&q=${Uri.encodeComponent(text)}"),
      ).timeout(const Duration(seconds: 5));
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && data.isNotEmpty && data[0] is List) {
          final translations = data[0] as List;
          final translatedText = translations.map((t) => t[0]).join('');
          return translatedText;
        }
      }
    } catch (e) {
      // Fallback: return original text with note
      return 'الترجمة غير متاحة: $text';
    }
    return text;
  }

  static Future<http.Response> _requestWithFallback(
    Future<http.Response> Function(String baseUrl) request,
  ) async {
    final tried = <String>{};
    Object? lastError;

    if (_activeBaseUrl != null) {
      try {
        final res = await request(_activeBaseUrl!).timeout(const Duration(seconds: 8));
        if (res.statusCode < 500) return res;
      } catch (e) {
        lastError = e;
      }
      tried.add(_activeBaseUrl!);
    }

    for (final base in _baseUrls) {
      if (tried.contains(base)) continue;
      try {
        final res = await request(base).timeout(const Duration(seconds: 8));
        if (res.statusCode < 500) {
          _activeBaseUrl = base;
          return res;
        }
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception("Backend unreachable on all configured hosts. Last error: $lastError");
  }
}