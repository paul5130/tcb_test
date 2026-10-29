import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_date_value/models/stock_day.dart';
import 'package:stock_date_value/services/stock_service.dart';

void main() {
  final fixture = File('test/fixtures/stock_day.json').readAsStringSync();
  final json = jsonDecode(fixture) as Map<String, dynamic>;
  test('實際 JSON 依欄名解析、忽略額外註記欄', () {
    final result = StockResult.fromJson(json);
    expect(result.rows.length, 20);
    expect(stockColumns, [
      '日期',
      '成交股數',
      '成交金額',
      '開盤價',
      '最高價',
      '最低價',
      '收盤價',
      '漲跌價差',
      '成交筆數',
    ]);
    expect(result.rows.first.values, [
      31855287,
      77463413685,
      2395,
      2440,
      2390,
      2440,
      35,
      65271,
    ]);
    expect(List.generate(9, result.rows.first.display), [
      '115/09/01',
      '31,855,287',
      '77,463,413,685',
      '2,395.00',
      '2,440.00',
      '2,390.00',
      '2,440.00',
      '+35.00',
      '65,271',
    ]);
    expect(result.rows.first.change, 35);
    final fields = List.of(json['fields'] as List).reversed.toList();
    final row = List.of((json['data'] as List).first as List).reversed.toList();
    expect(StockDay.fromRow(fields, row).values, result.rows.first.values);
  });
  test('民國與 API 日期、無效日期', () {
    expect(parseRocDate('108/06/03'), DateTime(2019, 6, 3));
    expect(rocMonth(DateTime(2019, 6)), '108/06');
    expect(apiDate(DateTime(2019, 6, 30)), '20190601');
    expect(() => parseRocDate('115/02/30'), throwsFormatException);
  });
  test('數值、千分位、缺值與特殊值', () {
    expect(parseStockNumber('77,463,413,685'), 77463413685);
    expect(parseStockNumber('X0.00'), 0);
    expect(parseStockNumber(''), isNull);
    expect(parseStockNumber('--'), isNull);
    expect(parseStockNumber(null), isNull);
    expect(() => parseStockNumber('abc'), throwsFormatException);
    expect(formatNumber(1234567, integer: true), '1,234,567');
    expect(formatNumber(null), '—');
  });
  test('漲跌正負與零格式', () {
    expect(formatNumber(parseStockNumber('+35.00'), signed: true), '+35.00');
    expect(formatNumber(parseStockNumber('-55.00'), signed: true), '-55.00');
    expect(formatNumber(parseStockNumber(' 0.00'), signed: true), '0.00');
    expect(formatNumber(-0.0, signed: true), '0.00');
    expect(StockResult.fromJson(json).rows[11].changeNote, contains('X0.00'));
  });
  final rows = [
    StockDay(date: DateTime(2026, 10, 2), values: List.filled(8, 100)),
    StockDay(date: DateTime(2026, 9, 30), values: List.filled(8, 9)),
    StockDay(date: DateTime(2026, 10, 1), values: List.filled(8, null)),
  ];
  test('八個數字欄位數值升降冪、缺值置後', () {
    for (var column = 1; column < 9; column++) {
      expect(sortStockDays(rows, column, true).map((r) => r.values.first), [
        9,
        100,
        null,
      ]);
      expect(sortStockDays(rows, column, false).map((r) => r.values.first), [
        100,
        9,
        null,
      ]);
    }
    expect(rows.first.values.first, 100);
  });
  test('日期跨月份排序', () {
    expect(sortStockDays(rows, 0, true).map((r) => r.date), [
      DateTime(2026, 9, 30),
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 2),
    ]);
    expect(sortStockDays(rows, 0, false).first.date, DateTime(2026, 10, 2));
  });
  test('空資料及 API 業務錯誤', () {
    expect(
      StockResult.fromJson({'stat': '很抱歉，沒有符合條件的資料!', 'total': 0}).rows,
      isEmpty,
    );
    expect(
      () => StockResult.fromJson({'stat': '查詢日期大於今日，請重新查詢!', 'total': 0}),
      throwsA(isA<StockApiException>()),
    );
    expect(
      () => StockResult.fromJson({'stat': 'OK', 'fields': [], 'data': []}),
      throwsFormatException,
    );
    expect(() => StockResult.fromJson([]), throwsFormatException);
  });
  test('HTTP 參數與成功結果', () async {
    final service = StockService(
      client: MockClient((request) async {
        expect(request.url.queryParameters, {
          'response': 'json',
          'date': '20190601',
          'stockNo': '2330',
        });
        return http.Response(
          fixture,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(service.close);
    expect(
      (await service.fetch(month: DateTime(2019, 6), stockNo: '2330')).rows,
      hasLength(20),
    );
  });
  for (final entry in <String, Future<http.Response> Function(http.Request)>{
    'HTTP': (_) async => http.Response('error', 503),
    'JSON': (_) async => http.Response('<html>', 200),
    '網路': (_) async => throw http.ClientException('offline'),
    '逾時': (_) => Completer<http.Response>().future,
  }.entries) {
    test('${entry.key} 錯誤轉成繁體中文例外', () async {
      final service = StockService(
        client: MockClient(entry.value),
        timeout: const Duration(milliseconds: 10),
      );
      addTearDown(service.close);
      await expectLater(
        service.fetch(month: DateTime(2026, 9), stockNo: '2330'),
        throwsA(isA<StockApiException>()),
      );
    });
  }
  test('拒絕空白股票代碼且不發送請求', () async {
    final service = StockService(
      client: MockClient((_) async => throw StateError('不應發送')),
    );
    addTearDown(service.close);
    await expectLater(
      service.fetch(month: DateTime(2026, 9), stockNo: ''),
      throwsA(isA<StockApiException>()),
    );
  });
}
