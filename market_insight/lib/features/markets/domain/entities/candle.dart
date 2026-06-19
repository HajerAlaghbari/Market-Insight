class CandleEntity {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;

  const CandleEntity({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}