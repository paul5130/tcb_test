const stockColumns = [
  '日期',
  '成交股數',
  '成交金額',
  '開盤價',
  '最高價',
  '最低價',
  '收盤價',
  '漲跌價差',
  '成交筆數',
];

bool isChangeColumn(int column) => stockColumns[column] == '漲跌價差';
bool isIntegerColumn(int column) =>
    const ['成交股數', '成交金額', '成交筆數'].contains(stockColumns[column]);

DateTime parseRocDate(String value) {
  final parts = value.trim().split('/');
  if (parts.length != 3) throw const FormatException('日期格式異常');
  final year = int.parse(parts[0]) + 1911;
  final month = int.parse(parts[1]);
  final day = int.parse(parts[2]);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw const FormatException('日期無效');
  }
  return date;
}

String rocMonth(DateTime date) =>
    '${date.year - 1911}/${date.month.toString().padLeft(2, '0')}';
String apiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}01';

num? parseStockNumber(Object? value) {
  if (value == null) return null;
  final raw = value.toString().trim().replaceAll(',', '').replaceAll('−', '-');
  if (raw.isEmpty || RegExp(r'^[-—]+$').hasMatch(raw)) return null;
  // TWSE uses X for ex-right/dividend reference-price adjustments.
  final normalized = raw.replaceFirst(RegExp(r'^[Xx]'), '');
  final result = num.tryParse(normalized);
  if (result == null || !result.isFinite) throw const FormatException('數值格式異常');
  return result;
}

String formatNumber(num? value, {bool integer = false, bool signed = false}) {
  if (value == null) return '—';
  final normalized = value == 0 ? 0 : value;
  final parts = normalized.toStringAsFixed(integer ? 0 : 2).split('.');
  parts[0] = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '${signed && normalized > 0 ? '+' : ''}${parts.join('.')}';
}

class StockDay {
  StockDay({required this.date, required this.values, this.changeNote = ''});
  final DateTime date;
  // Display order, excluding the date. Null means a missing official value.
  final List<num?> values;
  final String changeNote;
  num? get change => values[stockColumns.indexOf('漲跌價差') - 1];

  factory StockDay.fromRow(List<dynamic> fields, List<dynamic> row) {
    Object? read(String name) {
      final index = fields.indexOf(name);
      if (index < 0 || index >= row.length) throw FormatException('缺少欄位：$name');
      final value = row[index];
      if (value != null && value is! String && value is! num) {
        throw const FormatException('欄位格式異常');
      }
      return value;
    }

    final rawDate = read('日期');
    if (rawDate is! String) throw const FormatException('缺少日期');
    final rawChange = read('漲跌價差')?.toString().trim() ?? '';
    return StockDay(
      date: parseRocDate(rawDate),
      values: List.unmodifiable(
        stockColumns.skip(1).map((name) => parseStockNumber(read(name))),
      ),
      changeNote: rawChange.startsWith('X')
          ? 'X：除權息等參考價調整（原始值 $rawChange）'
          : '',
    );
  }

  String display(int column) => column == 0
      ? '${rocMonth(date)}/${date.day.toString().padLeft(2, '0')}'
      : formatNumber(
          values[column - 1],
          integer: isIntegerColumn(column),
          signed: isChangeColumn(column),
        );
}

List<StockDay> sortStockDays(List<StockDay> rows, int column, bool ascending) {
  final result = List<StockDay>.of(rows);
  result.sort((a, b) {
    int comparison;
    if (column == 0) {
      comparison = a.date.compareTo(b.date);
    } else {
      final left = a.values[column - 1];
      final right = b.values[column - 1];
      // Missing values remain last in both directions.
      if (left == null || right == null) {
        return left == right
            ? a.date.compareTo(b.date)
            : (left == null ? 1 : -1);
      }
      comparison = left.compareTo(right);
    }
    if (comparison == 0) return a.date.compareTo(b.date);
    return ascending ? comparison : -comparison;
  });
  return result;
}

class StockResult {
  const StockResult({required this.title, required this.rows});
  final String title;
  final List<StockDay> rows;

  factory StockResult.fromJson(Object? json) {
    if (json is! Map<String, dynamic> || json['stat'] is! String) {
      throw const FormatException('回應格式異常');
    }
    final status = json['stat'] as String;
    if (status.contains('沒有符合條件')) {
      return const StockResult(title: '', rows: []);
    }
    if (status != 'OK') throw StockApiException('證交所回應：$status');
    final fields = json['fields'];
    final data = json['data'];
    if (fields is! List ||
        data is! List ||
        json['title'] is! String ||
        !stockColumns.every(fields.contains)) {
      throw const FormatException('缺少必要欄位');
    }
    return StockResult(
      title: json['title'] as String,
      rows: List.unmodifiable(
        data.map((row) {
          if (row is! List) throw const FormatException('資料列格式異常');
          return StockDay.fromRow(fields, row);
        }),
      ),
    );
  }
}

class StockApiException implements Exception {
  const StockApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
