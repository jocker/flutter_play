import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/widgets/table_view/table_view_controller.dart';
import 'package:vgbnd/widgets/table_view/table_view_data_source.dart';




typedef Widget? BuildBodyRowFunc(BuildContext context, TableViewController controller, int viewType, int renderIndex);
typedef Widget? BuildBodyCellFunc(BuildContext context, TableColumn col, TableViewController controller, int index);
typedef Widget? BuildHeaderCellFunc(BuildContext context, TableColumn col, TableViewController controller);
typedef TableRowClickCallback(TableViewController controller, int renderIndex);

class TableColumn {
  final String key;
  double width = 0;
  int flex = 0;
  String? label;
  bool sortable = false;
  BuildHeaderCellFunc? buildHeaderCellFunc;
  BuildBodyCellFunc? buildBodyCellFunc;
  Alignment? contentAlignment;

  TableColumn(this.key,
      {double? width,
      int? flex,
      this.label,
      bool? sortable,
      this.buildHeaderCellFunc,
      this.buildBodyCellFunc,
      this.contentAlignment}) {
    this.width = width ?? this.width;
    this.flex = flex ?? this.flex;
    if (this.width < 0) {
      this.width = 0;
    }
    if (this.flex < 0) {
      this.flex = 0;
    }
    if (this.width == 0 && this.flex == 0) {
      this.flex = 1;
    }

    this.sortable = sortable ?? this.sortable;
  }

  TextStyle getDefaultTextStyleForHeader(BuildContext context, TableViewController controller) {
    final theme = Theme.of(context);
    final color = theme.primaryColor;

    final sortDir = controller.getSortDirection(this);

    return TextStyle(
        color: color, fontWeight: sortDir != SortDirection.None ? FontWeight.w700 : FontWeight.w500, fontSize: 15);
  }

  Widget _buildHeaderCell(BuildContext context, TableColumn col, TableViewController controller) {
    final fn = col.buildHeaderCellFunc;
    if (fn != null) {
      final w = fn(context, col, controller);
      if (w != null) {
        return w;
      }
    }

    final theme = Theme.of(context);

    final sortDir = controller.getSortDirection(this);

    var style = getDefaultTextStyleForHeader(context, controller);
    if (sortDir != SortDirection.None) {
      style = style.copyWith(color: theme.primaryColorDark, fontSize: 16);
    }
    Widget widget = Text(
      col.label ?? "",
      style: style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );

    if (col.sortable) {
      IconData iconData;

      switch (sortDir) {
        case SortDirection.Asc:
          iconData = Icons.arrow_drop_down;
          break;
        case SortDirection.Desc:
          iconData = Icons.arrow_drop_up;
          break;
        case SortDirection.None:
        default:
          iconData = Icons.unfold_more;
          break;
      }
      widget = InkWell(
          onTap: () {
            controller.setSortDirection(this, getNextSortDirection(sortDir));
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: widget),
              Icon(
                iconData,
                color: theme.primaryColor,
              ),
            ],
          ));
    }

    return widget;
  }

  Widget _buildBodyCell(BuildContext context, TableColumn col, TableViewController controller, int renderIndex) {
    final fn = col.buildBodyCellFunc;
    if (fn != null) {
      final w = fn(context, col, controller, renderIndex);
      if (w != null) {
        return w;
      }
    }

    final x = controller.getDatasourceValueAt<Object>(this.key, renderIndex: renderIndex);
    return Text(x?.toString() ?? "");
  }
}

class TableView extends StatefulWidget {
  final List<TableColumn> columns;
  late final double headerDividerWidth;
  late final Color? headerDividerColor;
  late final TableViewController controller;
  final SqlQueryDataSource dataSource;
  BuildBodyRowFunc? buildBodyRowFunc;
  final String? emptyText;
  TableRowClickCallback? onRowClick;

  TableView(
      {Key? key,
      required this.columns,
      double? headerDividerWidth,
      this.headerDividerColor,
      TableViewController? controller,
      this.buildBodyRowFunc,
      this.emptyText,
      required this.dataSource,
      this.onRowClick})
      : super(key: key) {
    this.headerDividerWidth = headerDividerWidth ?? 2;
    this.controller = controller ?? TableViewController();
    this.controller.dataSource = this.dataSource;
  }

  @override
  State<StatefulWidget> createState() {
    return _TableViewState();
  }
}

class _TableViewState extends State<TableView> {
  final List<double> _columnWidths = [];
  double columnWidthsSignature = 0;

  @override
  void initState() {
    super.initState();
    this.widget.controller.addListener(() {
      this.setState(() {});
    });
  }

  @override
  void dispose() {
    this.widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      initialData: TableViewDataSource.STATE_NONE,
      stream: widget.dataSource.stateChanged,
      builder: (context, snapshot) {
        print("snapshot ${snapshot.data}");

        switch (snapshot.data) {
          case TableViewDataSource.STATE_NONE:
            widget.dataSource.getItemAt(0);
            break;
          case TableViewDataSource.STATE_PROVISIONING:
            return Center(
              child: CircularProgressIndicator(),
            );
          case TableViewDataSource.STATE_ERROR:
            return Center(
              child: Text("Error loading data"),
            );
          case TableViewDataSource.STATE_LOADING_MORE:
            return _buildList(context);
          case TableViewDataSource.STATE_IDLE:
            if (this.widget.dataSource.isEmpty) {
              return Center(
                child: Text(this.widget.emptyText ?? "No items"),
              );
            }
            return _buildList(context);
        }

        return Container();
      },
    );
  }

  Widget _buildList(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        this._refreshColumnWidths(context, constraints);
        return Stack(
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(top: 50),
              // color: theme.secondaryHeaderColor,
              child: ListView.builder(
                controller: widget.controller.scrollController,
                itemCount: widget.controller.renderItemCount,
                itemBuilder: (context, index) {
                  return _buildBodyRow(context, index);
                },
              ),
            ),
            Container(
              height: 56,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(120),
                    offset: Offset(0.0, 1.0), //(x,y)
                    blurRadius: 2.0,
                  ),
                ],
              ),
              child: Row(
                children: _buildHeaders(context),
              ),
            ),
          ],
        );
      },
    );
  }

  _refreshColumnWidths(BuildContext context, BoxConstraints constraints) {
    final columnWidthsSignature = constraints.maxWidth;
    if (this.columnWidthsSignature == columnWidthsSignature) {
      return;
    }
    this.columnWidthsSignature = columnWidthsSignature;

    double availableWidth = constraints.maxWidth - (this.widget.columns.length - 1) * this.widget.headerDividerWidth;
    int totalFlex = 0;

    final columnWidths = HashMap<TableColumn, double>();

    columnWidths.clear();
    final List<TableColumn> flexCols = [];

    for (final col in this.widget.columns) {
      if (col.width > 0) {
        availableWidth -= col.width;
        columnWidths[col] = col.width.toDouble();
      } else if (col.flex > 0) {
        totalFlex += col.flex;
        flexCols.add(col);
      } else {
        columnWidths[col] = 0;
      }
    }

    if (flexCols.isNotEmpty) {
      final flexUnitSize = availableWidth / totalFlex;
      for (final col in flexCols) {
        columnWidths[col] = flexUnitSize * col.flex;
      }
    }

    _columnWidths.clear();
    _columnWidths.addAll(this.widget.columns.map((col) => columnWidths[col]!));
  }

  List<Widget> _buildHeaders(BuildContext ctx) {
    final List<Widget> widgets = [];

    final cols = this.widget.columns;
    for (int i = 0; i < cols.length; i++) {
      final col = cols[i];
      final isLast = cols.indexOf(col) == cols.length - 1;

      final colWidget = Container(
        alignment: col.contentAlignment ?? Alignment.centerLeft,
        width: _getColumnWidth(col),
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: col._buildHeaderCell(context, col, this.widget.controller),
      );

      widgets.add(colWidget);

      if (!isLast) {
        if (this.widget.headerDividerWidth > 0) {
          widgets.add(VerticalDivider(
            width: this.widget.headerDividerWidth,
            color: this.widget.headerDividerColor ?? Theme.of(ctx).primaryColorLight,
          ));
        }
      }
    }

    return widgets;
  }

  double _getColumnWidth(TableColumn col) {
    final idx = this.widget.columns.indexOf(col);
    if (idx < 0) {
      return 0;
    }
    return _columnWidths[idx];
  }

  _buildBodyRow(BuildContext context, int renderIndex) {
    final viewType = widget.controller.getItemViewType(renderIndex);
    final buildBodyRowFunc = widget.buildBodyRowFunc;
    if (buildBodyRowFunc != null) {
      final w = buildBodyRowFunc(context, widget.controller, viewType, renderIndex);
      if (w != null) {
        return w;
      }
    }

    switch (viewType) {
      case TableViewController.ITEM_VIEW_TYPE_FAB_SPACER:
        return SizedBox(
          height: 100,
        );
      case TableViewController.ITEM_VIEW_TYPE_DATASOURCE_ITEM:
        final theme = Theme.of(context);
        final columns = this.widget.columns;
        final List<Widget> widgets = [];
        for (var i = 0; i < columns.length; i++) {
          final col = columns[i];
          double leftMargin = 0;
          double width = _getColumnWidth(col);
          if (i > 0) {
            leftMargin += this.widget.headerDividerWidth;
          }

          final w = Container(
            alignment: col.contentAlignment ?? Alignment.centerLeft,
            margin: EdgeInsets.only(left: leftMargin),
            padding: EdgeInsets.only(left: 8, right: 8),
            height: 56,
            width: width,
            child: col._buildBodyCell(context, col, this.widget.controller, renderIndex),
          );
          widgets.add(w);
        }

        final bodyRow = Container(
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
            color: theme.primaryColorLight,
            width: 1,
          ))),
          child: Row(
            children: widgets,
          ),
        );

        final onRowClick = this.widget.onRowClick;
        if (onRowClick != null) {
          return InkWell(
            child: bodyRow,
            onTap: () {
              onRowClick(this.widget.controller, renderIndex);
            },
          );
        }

        return bodyRow;

      default:
        return Container();
    }
  }
}
