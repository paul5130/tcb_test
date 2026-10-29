import 'package:flutter/material.dart';
import 'package:stock_date_value/models/stock_day.dart';

class StockDataTable extends StatefulWidget {
  const StockDataTable({super.key, required this.rows});
  final List<StockDay> rows;
  @override
  State<StockDataTable> createState() => _StockDataTableState();
}

class _StockDataTableState extends State<StockDataTable> {
  int? _column;
  bool _ascending = true;
  final _horizontal = ScrollController();
  final _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = sortStockDays(widget.rows, _column ?? 0, _ascending);
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        controller: _horizontal,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth < 1180 ? 1180 : constraints.maxWidth,
            child: Scrollbar(
              controller: _vertical,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _vertical,
                padding: const EdgeInsets.only(bottom: 18),
                child: DataTable(
                  sortColumnIndex: _column,
                  sortAscending: _ascending,
                  columnSpacing: 24,
                  headingRowColor: WidgetStatePropertyAll(
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  columns: List.generate(
                    stockColumns.length,
                    (index) => DataColumn(
                      label: Text(stockColumns[index]),
                      numeric: index > 0,
                      onSort: (column, _) => setState(() {
                        _ascending = _column == column ? !_ascending : true;
                        _column = column;
                      }),
                    ),
                  ),
                  rows: rows
                      .map(
                        (row) => DataRow(
                          cells: List.generate(9, (index) {
                            final change = row.change;
                            final color =
                                !isChangeColumn(index) || change == null
                                ? null
                                : change > 0
                                ? Colors.red.shade700
                                : change < 0
                                ? Colors.green.shade800
                                : Colors.black;
                            final text = Text(
                              row.display(index),
                              style: TextStyle(color: color),
                            );
                            return DataCell(
                              isChangeColumn(index) && row.changeNote.isNotEmpty
                                  ? Tooltip(
                                      message: row.changeNote,
                                      child: text,
                                    )
                                  : text,
                            );
                          }),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
