import 'package:flutter/material.dart';
import 'pages/stock_page.dart';

void main() => runApp(const StockApp());

class StockApp extends StatelessWidget {
  const StockApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '台灣股票每日成交資訊',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF174A68)),
    ),
    home: const StockPage(),
  );
}
