import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_date_value/pages/stock_page.dart';
import 'package:stock_date_value/services/stock_service.dart';

void main() {
  final fixture = File('test/fixtures/stock_day.json').readAsStringSync();
  testWidgets('手機查詢、重複點擊、成功及欄位排序', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    final completer = Completer<http.Response>();
    final service = StockService(
      client: MockClient((_) {
        calls++;
        return completer.future;
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(MaterialApp(home: StockPage(service: service)));
    expect(find.text('請選擇年月並輸入股票代碼，開始查詢。'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '2330');
    await tester.tap(find.text('查詢'));
    await tester.pump();
    await tester.tap(find.text('查詢中'));
    expect(calls, 1);
    completer.complete(http.Response.bytes(utf8.encode(fixture), 200));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
    expect(tester.takeException(), isNull);
    final table = tester.widget<DataTable>(find.byType(DataTable));
    table.columns[1].onSort!(1, true);
    await tester.pump();
    expect(
      tester.widget<DataTable>(find.byType(DataTable)).sortAscending,
      isTrue,
    );
    tester.widget<DataTable>(find.byType(DataTable)).columns[1].onSort!(
      1,
      false,
    );
    await tester.pump();
    expect(
      tester.widget<DataTable>(find.byType(DataTable)).sortAscending,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('請求返回前 dispose 不更新頁面', (tester) async {
    final completer = Completer<http.Response>();
    final service = StockService(client: MockClient((_) => completer.future));
    addTearDown(service.close);
    await tester.pumpWidget(MaterialApp(home: StockPage(service: service)));
    await tester.enterText(find.byType(TextFormField), '2330');
    await tester.tap(find.text('查詢'));
    await tester.pumpWidget(const SizedBox());
    completer.complete(http.Response.bytes(utf8.encode(fixture), 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
