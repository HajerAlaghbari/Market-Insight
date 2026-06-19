import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // App Title
      'app_title': 'Market Insight',
      
      // Bottom Navigation
      'nav_metals': 'Metals',
      'nav_fx': 'FX',
      'nav_news': 'News',
      'nav_crypto': 'Crypto',
      'nav_stocks': 'Stocks',
      
      // Symbol Details
      'overview': 'Overview',
      'analyze': 'Analyze',
      'bid': 'Bid',
      'ask': 'Ask',
      
      // Paper Trading
      'paper_trading': 'Paper Trading',
      'portfolio_summary': 'Portfolio Summary',
      'current_balance': 'Current Balance',
      'total_value': 'Total Value',
      'roi': 'Return on Investment',
      'total_profit_loss': 'Total Profit/Loss',
      'performance_stats': 'Performance Statistics',
      'total_trades': 'Total Trades',
      'winning_trades': 'Winning Trades',
      'losing_trades': 'Losing Trades',
      'win_rate': 'Win Rate',
      'profit_factor': 'Profit Factor',
      'open_positions': 'Open Positions',
      'trade_history': 'Trade History',
      'no_open_positions': 'No open positions',
      'no_trade_history': 'No trade history',
      'close': 'Close',
      'buy': 'Buy',
      'sell': 'Sell',
      'quantity': 'Quantity',
      'profit': 'Profit',
      'loss': 'Loss',
      'reset_portfolio': 'Reset Portfolio',
      'reset_confirm_title': 'Reset Portfolio',
      'reset_confirm_message': 'Are you sure you want to reset your portfolio? All trades will be deleted.',
      'cancel': 'Cancel',
      'reset': 'Reset',
      'portfolio_reset_success': 'Portfolio reset successfully',
      'trade_closed_profit': 'Trade closed: Profit',
      'trade_closed_loss': 'Trade closed: Loss',
      'error_loading_data': 'Error loading data',
      'error_closing_trade': 'Error closing trade',
      'insufficient_balance': 'Insufficient balance',
      
      // Signals
      'signal': 'Signal',
      'buy_signal': 'BUY',
      'sell_signal': 'SELL',
      'hold_signal': 'HOLD',
      'confidence': 'Confidence',
      'technical_analysis': 'Technical Analysis',
      'news_sentiment': 'News Sentiment',
      'hybrid_signal': 'Hybrid Signal',
      
      // Market Categories
      'crypto': 'Cryptocurrency',
      'metals': 'Metals',
      'fx': 'Foreign Exchange',
      'stocks': 'Stocks',
      
      // Common
      'loading': 'Loading...',
      'error': 'Error',
      'refresh': 'Refresh',
      'settings': 'Settings',
      'language': 'Language',
      'english': 'English',
      'arabic': 'العربية',
      'price': 'Price',
      'change': 'Change',
      'volume': 'Volume',
      'high': 'High',
      'low': 'Low',
      'open': 'Open',
      'close_price': 'Close',
      
      // News
      'latest_news': 'Latest News',
      'bullish': 'Bullish',
      'bearish': 'Bearish',
      'neutral': 'Neutral',
      'impact_score': 'Impact Score',
      'sentiment': 'Sentiment',
      'read_more': 'Read More',
      
      // Signal Modes
      'auto_signal': 'Auto Signal',
      'manual_signal': 'Manual Signal',
      'generate_signal': 'Generate Signal',
      'tap_to_generate': 'Tap to generate a signal',
      'next_candle_close': 'Next candle:',
      'waiting_candle_close': 'Waiting for candle to close...\nSignal will appear automatically',

      // Timeframes
      'timeframe': 'Timeframe',
      '1m': '1 Minute',
      '5m': '5 Minutes',
      '15m': '15 Minutes',
      '30m': '30 Minutes',
      '1h': '1 Hour',
      '4h': '4 Hours',
      '1d': '1 Day',
      '1w': '1 Week',
      '1M': '1 Month',

      // Signal Review
      'signal_review': 'Signal Review',
      'signal_review_log': 'Signal Review Log',
      'total': 'Total',
      'resolved': 'Resolved',
      'correct': 'Correct',
      'accuracy': 'Accuracy',
      'pending': 'Pending',
      'incorrect': 'Incorrect',
      'clear_all': 'Clear all',
      'no_signals_yet': 'No signals logged yet',
      'no_signals_desc': 'Generate signals from the market page to start tracking.',
      'resolves_in': 'Resolves in:',
      'waiting_price': 'Waiting for price data...',
      'market_moved': 'Market moved:',
      'signal_matched': 'Signal matched market',
      'signal_not_matched': 'Signal did not match',
      'delete_all': 'Delete All',
      'clear_all_confirm': 'This will permanently delete all signal log entries.',
      'clear_logs': 'Clear All Logs?',
    },
    'ar': {
      // App Title
      'app_title': 'Market Insight',
      
      // Bottom Navigation
      'nav_metals': 'المعادن',
      'nav_fx': 'العملات',
      'nav_news': 'الأخبار',
      'nav_crypto': 'العملات الرقمية',
      'nav_stocks': 'الأسهم',
      
      // Symbol Details
      'overview': 'نظرة عامة',
      'analyze': 'تحليل',
      'bid': 'الشراء',
      'ask': 'البيع',
      
      // Paper Trading
      'paper_trading': 'التداول الوهمي',
      'portfolio_summary': 'ملخص المحفظة',
      'current_balance': 'الرصيد الحالي',
      'total_value': 'القيمة الإجمالية',
      'roi': 'العائد على الاستثمار',
      'total_profit_loss': 'الربح/الخسارة الإجمالي',
      'performance_stats': 'إحصائيات الأداء',
      'total_trades': 'إجمالي الصفقات',
      'winning_trades': 'الصفقات الرابحة',
      'losing_trades': 'الصفقات الخاسرة',
      'win_rate': 'نسبة النجاح',
      'profit_factor': 'عامل الربح',
      'open_positions': 'الصفقات المفتوحة',
      'trade_history': 'سجل الصفقات',
      'no_open_positions': 'لا توجد صفقات مفتوحة',
      'no_trade_history': 'لا يوجد سجل صفقات',
      'close': 'إغلاق',
      'buy': 'شراء',
      'sell': 'بيع',
      'quantity': 'الكمية',
      'profit': 'ربح',
      'loss': 'خسارة',
      'reset_portfolio': 'إعادة تعيين المحفظة',
      'reset_confirm_title': 'إعادة تعيين المحفظة',
      'reset_confirm_message': 'هل أنت متأكد من إعادة تعيين المحفظة؟ سيتم حذف جميع الصفقات.',
      'cancel': 'إلغاء',
      'reset': 'إعادة تعيين',
      'portfolio_reset_success': 'تم إعادة تعيين المحفظة بنجاح',
      'trade_closed_profit': 'تم إغلاق الصفقة: ربح',
      'trade_closed_loss': 'تم إغلاق الصفقة: خسارة',
      'error_loading_data': 'خطأ في تحميل البيانات',
      'error_closing_trade': 'خطأ في إغلاق الصفقة',
      'insufficient_balance': 'رصيد غير كافٍ',
      
      // Signals
      'signal': 'الإشارة',
      'buy_signal': 'شراء',
      'sell_signal': 'بيع',
      'hold_signal': 'انتظار',
      'confidence': 'الثقة',
      'technical_analysis': 'التحليل الفني',
      'news_sentiment': 'تحليل الأخبار',
      'hybrid_signal': 'الإشارة الهجينة',
      
      // Market Categories
      'crypto': 'العملات الرقمية',
      'metals': 'المعادن',
      'fx': 'العملات الأجنبية',
      'stocks': 'الأسهم',
      
      // Common
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'refresh': 'تحديث',
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'english': 'English',
      'arabic': 'العربية',
      'price': 'السعر',
      'change': 'التغيير',
      'volume': 'الحجم',
      'high': 'الأعلى',
      'low': 'الأدنى',
      'open': 'الافتتاح',
      'close_price': 'الإغلاق',
      
      // News
      'latest_news': 'آخر الأخبار',
      'bullish': 'إيجابي',
      'bearish': 'سلبي',
      'neutral': 'محايد',
      'impact_score': 'درجة التأثير',
      'sentiment': 'المشاعر',
      'read_more': 'اقرأ المزيد',
      
      // Signal Modes
      'auto_signal': 'إشارة تلقائية',
      'manual_signal': 'إشارة يدوية',
      'generate_signal': 'توليد إشارة',
      'tap_to_generate': 'اضغط لتوليد الإشارة',
      'next_candle_close': 'الشمعة القادمة:',
      'waiting_candle_close': 'بانتظار إغلاق الشمعة...\nستظهر الإشارة تلقائياً',

      // Timeframes
      'timeframe': 'الإطار الزمني',
      '1m': '1د',
      '5m': '5د',
      '15m': '15د',
      '30m': '30د',
      '1h': '1س',
      '4h': '4س',
      '1d': '1ي',
      '1w': '1أ',
      '1M': '1ش',

      // Signal Review
      'signal_review': 'مراجعة التوصيات',
      'signal_review_log': 'سجل مراجعة التوصيات',
      'total': 'الكلي',
      'resolved': 'محلول',
      'correct': 'صحيح',
      'accuracy': 'الدقة',
      'pending': 'بانتظار',
      'incorrect': 'خاطئ',
      'clear_all': 'حذف الكل',
      'no_signals_yet': 'لا توجد توصيات مسجلة بعد',
      'no_signals_desc': 'ولّد إشارات من صفحة الأسواق لبدء التتبع.',
      'resolves_in': 'يُحل بعد:',
      'waiting_price': 'بانتظار بيانات السعر...',
      'market_moved': 'تحرك السوق:',
      'signal_matched': 'التوصية تطابقت مع السوق',
      'signal_not_matched': 'التوصية لم تتطابق',
      'delete_all': 'حذف الكل',
      'clear_all_confirm': 'سيتم حذف جميع سجلات التوصيات نهائياً.',
      'clear_logs': 'حذف جميع السجلات؟',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  String get appTitle => translate('app_title');
  String get navMetals => translate('nav_metals');
  String get navFx => translate('nav_fx');
  String get navNews => translate('nav_news');
  String get navCrypto => translate('nav_crypto');
  String get navStocks => translate('nav_stocks');
  String get overview => translate('overview');
  String get analyze => translate('analyze');
  String get bid => translate('bid');
  String get ask => translate('ask');
  String get paperTrading => translate('paper_trading');
  String get portfolioSummary => translate('portfolio_summary');
  String get currentBalance => translate('current_balance');
  String get totalValue => translate('total_value');
  String get roi => translate('roi');
  String get totalProfitLoss => translate('total_profit_loss');
  String get performanceStats => translate('performance_stats');
  String get totalTrades => translate('total_trades');
  String get winningTrades => translate('winning_trades');
  String get losingTrades => translate('losing_trades');
  String get winRate => translate('win_rate');
  String get profitFactor => translate('profit_factor');
  String get openPositions => translate('open_positions');
  String get tradeHistory => translate('trade_history');
  String get noOpenPositions => translate('no_open_positions');
  String get noTradeHistory => translate('no_trade_history');
  String get close => translate('close');
  String get buy => translate('buy');
  String get sell => translate('sell');
  String get quantity => translate('quantity');
  String get profit => translate('profit');
  String get loss => translate('loss');
  String get resetPortfolio => translate('reset_portfolio');
  String get resetConfirmTitle => translate('reset_confirm_title');
  String get resetConfirmMessage => translate('reset_confirm_message');
  String get cancel => translate('cancel');
  String get reset => translate('reset');
  String get portfolioResetSuccess => translate('portfolio_reset_success');
  String get tradeClosedProfit => translate('trade_closed_profit');
  String get tradeClosedLoss => translate('trade_closed_loss');
  String get errorLoadingData => translate('error_loading_data');
  String get errorClosingTrade => translate('error_closing_trade');
  String get insufficientBalance => translate('insufficient_balance');
  String get signal => translate('signal');
  String get buySignal => translate('buy_signal');
  String get sellSignal => translate('sell_signal');
  String get holdSignal => translate('hold_signal');
  String get confidence => translate('confidence');
  String get technicalAnalysis => translate('technical_analysis');
  String get newsSentiment => translate('news_sentiment');
  String get hybridSignal => translate('hybrid_signal');
  String get crypto => translate('crypto');
  String get metals => translate('metals');
  String get fx => translate('fx');
  String get stocks => translate('stocks');
  String get loading => translate('loading');
  String get error => translate('error');
  String get refresh => translate('refresh');
  String get settings => translate('settings');
  String get language => translate('language');
  String get english => translate('english');
  String get arabic => translate('arabic');
  String get price => translate('price');
  String get change => translate('change');
  String get volume => translate('volume');
  String get high => translate('high');
  String get low => translate('low');
  String get open => translate('open');
  String get closePrice => translate('close_price');
  String get latestNews => translate('latest_news');
  String get bullish => translate('bullish');
  String get bearish => translate('bearish');
  String get neutral => translate('neutral');
  String get impactScore => translate('impact_score');
  String get sentiment => translate('sentiment');
  String get readMore => translate('read_more');
  String get timeframe => translate('timeframe');

  // Signal Review
  String get signalReview => translate('signal_review');
  String get signalReviewLog => translate('signal_review_log');
  String get total => translate('total');
  String get resolved => translate('resolved');
  String get correct => translate('correct');
  String get accuracy => translate('accuracy');
  String get pending => translate('pending');
  String get incorrect => translate('incorrect');
  String get clearAll => translate('clear_all');
  String get noSignalsYet => translate('no_signals_yet');
  String get noSignalsDesc => translate('no_signals_desc');
  String get resolvesIn => translate('resolves_in');
  String get waitingPrice => translate('waiting_price');
  String get marketMoved => translate('market_moved');
  String get signalMatched => translate('signal_matched');
  String get signalNotMatched => translate('signal_not_matched');
  String get deleteAll => translate('delete_all');
  String get clearAllConfirm => translate('clear_all_confirm');
  String get clearLogs => translate('clear_logs');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
