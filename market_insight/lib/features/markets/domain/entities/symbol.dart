enum MarketCategory { crypto, metals, fx, stocks }

class SymbolEntity {
  final String code;
  final String name;
  final double bid;
  final double ask;
  final bool isUp;
  final String? signal;

  const SymbolEntity({
    required this.code,
    required this.name,
    required this.bid,
    required this.ask,
    required this.isUp,
    this.signal,
  });
}