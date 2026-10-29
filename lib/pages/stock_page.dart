import 'package:flutter/material.dart';
import 'package:stock_date_value/models/stock_day.dart';
import 'package:stock_date_value/services/stock_service.dart';
import 'package:stock_date_value/widgets/stock_data_table.dart';

enum QueryState { initial, loading, success, empty, error }

class StockPage extends StatefulWidget {
  const StockPage({super.key, this.service});
  final StockService? service;
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late final StockService _service = widget.service ?? StockService();
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  QueryState _state = QueryState.initial;
  StockResult? _result;
  String _message = '';
  String _queryTitle = '';
  bool get _loading => _state == QueryState.loading;

  @override
  void dispose() {
    _code.dispose();
    if (widget.service == null) _service.close();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    var year = _month.year;
    var month = _month.month;
    final now = DateTime.now();
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('選擇資料年月（民國）'),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: year,
                  decoration: const InputDecoration(labelText: '民國年'),
                  items: [
                    for (var y = now.year; y >= 2010; y--)
                      DropdownMenuItem(value: y, child: Text('${y - 1911} 年')),
                  ],
                  onChanged: (value) => update(() {
                    year = value!;
                    if (year == now.year && month > now.month) {
                      month = now.month;
                    }
                  }),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: ValueKey('$year/$month'),
                  initialValue: month,
                  decoration: const InputDecoration(labelText: '月份'),
                  items: [
                    for (
                      var m = 1;
                      m <= (year == now.year ? now.month : 12);
                      m++
                    )
                      DropdownMenuItem(value: m, child: Text('$m 月')),
                  ],
                  onChanged: (value) => update(() => month = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, DateTime(year, month)),
              child: const Text('確定'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _month = selected);
  }

  Future<void> _query() async {
    if (_loading || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final month = _month;
    final code = _code.text.trim();
    setState(() {
      _state = QueryState.loading;
      _result = null;
      _queryTitle = '$code · ${rocMonth(month)}';
    });
    try {
      final result = await _service.fetch(month: month, stockNo: code);
      if (!mounted) return;
      setState(() {
        _result = result;
        _state = result.rows.isEmpty ? QueryState.empty : QueryState.success;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = QueryState.error;
        _message = error is StockApiException ? error.message : '查詢失敗，請稍後重試。';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('台灣股票每日成交資訊')),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '個股歷史交易查詢',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('資料來源：臺灣證券交易所｜提供民國 99 年起上市證券資料'),
                  const SizedBox(height: 20),
                  Form(
                    key: _form,
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _pickMonth,
                            icon: const Icon(Icons.calendar_month),
                            label: Text('資料日期：${rocMonth(_month)}'),
                          ),
                        ),
                        SizedBox(
                          width: 250,
                          child: TextFormField(
                            controller: _code,
                            enabled: !_loading,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: '股票代碼',
                              hintText: '例如 2330',
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                            textInputAction: TextInputAction.search,
                            onFieldSubmitted: (_) => _query(),
                            validator: (value) =>
                                RegExp(
                                  r'^[0-9A-Za-z]{4,6}$',
                                ).hasMatch(value?.trim() ?? '')
                                ? null
                                : '請輸入 4 至 6 碼英數字代碼',
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _loading ? null : _query,
                          icon: const Icon(Icons.search),
                          label: Text(_loading ? '查詢中' : '查詢'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('請指定股票代碼；此 API 不提供空白代碼的全部股票查詢。'),
                  const SizedBox(height: 24),
                  if (_queryTitle.isNotEmpty)
                    Text(
                      '$_queryTitle · ${_result?.rows.length ?? 0} 筆',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  if (_state == QueryState.success) ...[
                    const SizedBox(height: 8),
                    Text(_result!.title),
                    const SizedBox(height: 8),
                    const Text('點擊欄位標題排序；紅色為上漲，綠色為下跌。— 表示缺值；X 調整值可查看提示。'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: (constraints.maxHeight * .65).clamp(280.0, 650.0),
                      child: StockDataTable(
                        key: ValueKey(_result),
                        rows: _result!.rows,
                      ),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: switch (_state) {
                          QueryState.loading => const Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('正在取得證交所資料…'),
                            ],
                          ),
                          QueryState.empty => const Text(
                            '查無資料，請確認股票代碼、上市時間或查詢月份。',
                          ),
                          QueryState.error => Text(
                            _message,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          _ => const Text('請選擇年月並輸入股票代碼，開始查詢。'),
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
