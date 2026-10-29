import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stock_date_value/models/stock_day.dart';

class StockService {
  StockService({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;

  Future<StockResult> fetch({
    required DateTime month,
    required String stockNo,
  }) async {
    if (!RegExp(r'^[0-9A-Za-z]{4,6}$').hasMatch(stockNo.trim())) {
      throw const StockApiException('請輸入 4 至 6 碼英數字股票代碼。');
    }
    final uri = Uri.https('www.twse.com.tw', '/rwd/zh/afterTrading/STOCK_DAY', {
      'response': 'json',
      'date': apiDate(month),
      'stockNo': stockNo.trim(),
    });
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) {
        throw StockApiException(
          '證交所服務暫時無法使用（HTTP ${response.statusCode}），請稍後重試。',
        );
      }
      return StockResult.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } on TimeoutException {
      throw const StockApiException('查詢逾時，請稍後重試。');
    } on FormatException {
      throw const StockApiException('證交所回傳資料格式異常，請稍後重試。');
    } on http.ClientException {
      throw const StockApiException('網路連線失敗，請確認網路或瀏覽器跨來源限制後重試。');
    }
  }

  void close() => _client.close();
}
