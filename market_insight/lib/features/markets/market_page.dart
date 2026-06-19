import 'package:flutter/material.dart';
import 'dart:async';
import '../../api_service.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  String price = "...";
  String signal = "...";
  static const String symbolCode = "BTCUSD";

  @override
  void initState() {
    super.initState();
    startFetching();
    ApiService.startStream(symbolCode);
  }

  void startFetching() {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final priceData = await ApiService.getPrice(symbolCode);
        final signalData = await ApiService.getSignal(symbolCode);

        setState(() {
          price = (priceData["price"] ?? "...").toString();
          signal = (signalData["signal"] ?? "HOLD").toString();
        });
      } catch (e) {
        debugPrint("Error: $e");
      }
    });
  }

  Color getSignalColor() {
    if (signal == "BUY") return Colors.green;
    if (signal == "SELL") return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(title: const Text("Market Insight")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Price: $price",
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 20),
            Text(
              "Signal: $signal",
              style: TextStyle(
                color: getSignalColor(),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}