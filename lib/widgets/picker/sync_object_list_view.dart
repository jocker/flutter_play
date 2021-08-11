import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vgbnd/ext.dart';
import 'package:vgbnd/helpers/sql_select_query.dart';
import 'package:vgbnd/models/product.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/widgets/search.dart';
import 'package:vgbnd/widgets/table_view/table_view.dart';
import 'package:vgbnd/widgets/table_view/table_view_controller.dart';
import 'package:vgbnd/widgets/table_view/table_view_data_source.dart';

class SyncObjectListView extends StatefulWidget {
  final SyncSchema schema;
  late final SqlSelectQueryBuilder query;
  late final String sqlColumnName;
  late final String sqlColumnSelector;
  final void Function(Object? obj) onItemClick;
  late final String title;

  static Future<dynamic> pickOne(SyncSchema schema, {String? title}) async {
    final lv = SyncObjectListView(
      title: title,
      schema: schema,
      onItemClick: (obj) {
        Get.back(result: obj);
      },
    );

    return await Get.to(lv);
  }

  SyncObjectListView(
      {Key? key,
      required this.schema,
      String? title,
      SqlSelectQueryBuilder? query,
      String? sqlColumnSelector,
      String? sqlColumnName,
      required this.onItemClick})
      : super(key: key) {
    final displayNameCol = this.schema.columns.firstWhereOrNull((col) => col.isDisplayNameColumn);

    this.sqlColumnSelector = sqlColumnSelector ?? displayNameCol?.name ?? "";

    if (this.sqlColumnSelector == "") {
      throw ArgumentError("sqlColumnSelector invalid");
    }

    this.query = query ?? SqlSelectQueryBuilder(schema.tableName)
      ..order(this.sqlColumnSelector);

    this.sqlColumnName = sqlColumnName ?? this.sqlColumnSelector;

    this.title = title ?? 'Pick ${schema.schemaName}';
  }

  @override
  _SyncObjectListViewState createState() {
    return _SyncObjectListViewState();
  }
}

class _SyncObjectListViewState extends State<SyncObjectListView> {
  late final SqlQueryDataSource dataSource;

  @override
  void initState() {
    dataSource = SqlQueryDataSource(SqlSelectQueryBuilder(Product.schema.tableName)..order(widget.sqlColumnSelector),
        textSearchSelector: widget.sqlColumnSelector);

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SearchAppBar(
        title: Text(this.widget.title),
        onSearchTextChanged: (arg) {
          dataSource.setCriteria(TableViewDataFilterCriteria(query: arg));
        },
      ),
      body: TableView(
        onRowClick: (controller, renderIndex) {
          final row = dataSource.getItemAt(renderIndex);
          if (row != null) {
            final obj = this.widget.schema.instantiate(row.toMap());
            this.widget.onItemClick(obj);
          }
        },
        controller: TableViewController(this.dataSource),
        headersVisible: false,
        columns: [
          TableColumn(
            this.widget.sqlColumnName,
          )
        ],
      ),
    );
  }
}
