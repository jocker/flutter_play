import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/data/cursor.dart';

abstract class TableViewDataSource extends ChangeNotifier {
  static const int STATE_NONE = 0, STATE_LOADING = 1, STATE_READY = 2, STATE_ERROR = 3;

  Cursor? _cursor;
  var _isDisposed = false;
  var _currentState = STATE_NONE;
  var _currentVersion = 0;
  Stream<int>? _stateChanged;

  Future<Cursor> initCursor();

  bool get isEmpty {
    return (_cursor?.count ?? 0) == 0;
  }

  int get dataVersion {
    return _currentVersion;
  }

  _initCursorIfNeeded() async {
    if (_setState(STATE_LOADING, prevStates: [STATE_NONE])) {
      try {
        //await Future.delayed(Duration(seconds: 2));
        _cursor = await initCursor();
        _setState(STATE_READY);
      } catch (e) {
        _setState(STATE_ERROR);
      }
    }
  }

  @override
  dispose() {
    if (!_isDisposed) {
      super.dispose();
      _isDisposed = true;
      _cursor = null;
    }
  }

  bool _setState(int newState, {List<int>? prevStates}) {
    if (_currentState != newState) {
      if (prevStates == null || prevStates.contains(_currentState)) {
        _currentState = newState;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  Stream<int> get stateChanged {
    _initCursorIfNeeded();
    var prevState = _currentState;
    _stateChanged = _stateChanged ?? _createStream(() => prevState != _currentState, () => _currentState);
    return _stateChanged!;
  }

  Stream<T> _createStream<T>(bool isChanged(), T getValue()) {
    StreamController<T>? controller;
    final VoidCallback stateListener = () {
      if (isChanged()) {
        controller?.sink.add(getValue());
      }
    };

    controller = StreamController(onListen: () {
      addListener(stateListener);
    }, onCancel: () {
      removeListener(stateListener);
    });

    return controller.stream;
  }

  invalidate() {
    _currentVersion += 1;
    _setState(STATE_NONE);
  }
}

class TableViewController extends ChangeNotifier {
  static const int ITEM_VIEW_TYPE_DATASOURCE_ITEM = 0, ITEM_VIEW_TYPE_GROUP_HEADER = 1, ITEM_VIEW_TYPE_FAB_SPACER = 2;

  final List<int> appendViewTypes = [];
  final List<int> prependViewTypes = [];

  String? _groupingColumn;

  final List<int> _groupNamesViewTypeIndices = [];
  int _lastCheckedGroupingIndex = -1;
  int? _lastDataSourceRenderIndex;

  final _scrollController = ScrollController();
  TableViewDataSource? _dataSource;

  final _sortDirections = new HashMap<TableColumn, SortDirection>();
  StreamSubscription? _streamSub;

  Cursor? get cursor {
    return this._dataSource?._cursor;
  }

  int get renderItemCount {
    return cursorCount + _groupNamesViewTypeIndices.length + appendViewTypes.length + prependViewTypes.length;
  }

  int get cursorCount {
    return cursor?.count ?? 0;
  }

  _clearGroupingInfo() {
    _groupNamesViewTypeIndices.clear();
    _lastCheckedGroupingIndex = -1;
    _lastDataSourceRenderIndex = null;
  }

  setGroupByColumn(String? columnName) {
    if (this._groupingColumn != columnName) {
      this._groupingColumn = columnName;
      this._clearGroupingInfo();
      this.notifyListeners();
    }
  }

  getSortDirection(TableColumn col) {
    return _sortDirections[col] ?? SortDirection.None;
  }

  setSortDirection(TableColumn col, SortDirection dir) {
    if (getSortDirection(col) != dir) {
      _sortDirections[col] = dir;
      notifyListeners();
    }
  }

  @override
  dispose() {
    super.dispose();
    _streamSub?.cancel();
  }

  getItemViewType(int renderIndex) {
    if (renderIndex < prependViewTypes.length) {
      return prependViewTypes[renderIndex];
    }
    _precacheViewTypesForGrouping(renderIndex);
    if (_groupNamesViewTypeIndices.contains(renderIndex)) {
      return ITEM_VIEW_TYPE_GROUP_HEADER;
    }
    final lastDsRenderIndex = _lastDataSourceRenderIndex ?? -1;
    final appendViewIndex = renderIndex - lastDsRenderIndex - 1;
    if (appendViewIndex >= 0 && appendViewIndex < appendViewTypes.length) {
      return appendViewTypes[appendViewIndex];
    }

    return ITEM_VIEW_TYPE_DATASOURCE_ITEM;
  }

  int getDatasourceIndex(int renderIndex) {
    final minIndexForDs = prependViewTypes.length;
    if (renderIndex < minIndexForDs) {
      return -1;
    }
    if (renderIndex == minIndexForDs) {
      return 0;
    }
    if (_groupNamesViewTypeIndices.isEmpty) {
      return renderIndex - minIndexForDs;
    }

    int offset = 0;
    for (final pos in _groupNamesViewTypeIndices) {
      if (pos < renderIndex) {
        offset += 1;
      } else {
        break;
      }
    }

    return renderIndex - offset - minIndexForDs;
  }

  T? getDatasourceValueAt<T>(String columnName, {int? renderIndex, int? datasourceIndex}) {
    final int cursorIndex = datasourceIndex ?? (renderIndex == null ? -1 : getDatasourceIndex(renderIndex));
    if (cursorIndex < 0) {
      return null;
    }
    final c = this.cursor;
    if (c == null || !c.moveToPosition(cursorIndex)) {
      return null;
    }
    return c.getValue(columnName: columnName);
  }

  _precacheViewTypesForGrouping(int renderIndex) {
    final pageSize = 50;
    if (renderIndex <= _lastCheckedGroupingIndex) {
      return;
    }

    final groupByColumn = _groupingColumn;

    if (_lastDataSourceRenderIndex != null) {
      return;
    } else if (groupByColumn == null) {
      _lastDataSourceRenderIndex = prependViewTypes.length + cursorCount;
      return;
    }
    if (renderIndex < prependViewTypes.length) {
      return;
    }
    int dsRenderIndex = (renderIndex ~/ pageSize) * pageSize;
    if (dsRenderIndex < prependViewTypes.length) {
      dsRenderIndex = prependViewTypes.length;
    }
    final c = this.cursor;

    if (_groupNamesViewTypeIndices.isNotEmpty && dsRenderIndex < _groupNamesViewTypeIndices.last) {
      dsRenderIndex = _groupNamesViewTypeIndices.last;
    }
    int dsIndex = getDatasourceIndex(dsRenderIndex);
    if (dsIndex < 0) {
      return;
    }
    final endIndex = dsIndex + pageSize;
    if (c == null || !c.moveToPosition(dsIndex)) {
      return;
    }
    Object? prevColumnValue;
    bool hasChanges = false;

    while (dsIndex < endIndex) {
      if (!c.moveToPosition(dsIndex)) {
        // reached the end of the data source
        _lastDataSourceRenderIndex = dsRenderIndex - 1;
        break;
      }

      int viewType = TableViewController.ITEM_VIEW_TYPE_DATASOURCE_ITEM;
      if (dsIndex == 0) {
        viewType = ITEM_VIEW_TYPE_GROUP_HEADER;
      } else {
        if (prevColumnValue == null) {
          prevColumnValue = this.getDatasourceValueAt(groupByColumn, datasourceIndex: dsIndex - 1);
        }
        final currentColumnValue = this.getDatasourceValueAt(groupByColumn, datasourceIndex: dsIndex);
        if (currentColumnValue != null && (currentColumnValue != prevColumnValue)) {
          viewType = ITEM_VIEW_TYPE_GROUP_HEADER;
        }
        prevColumnValue = currentColumnValue;
      }

      if (viewType == ITEM_VIEW_TYPE_GROUP_HEADER) {
        _groupNamesViewTypeIndices.add(dsRenderIndex);
        dsRenderIndex += 1;
        hasChanges = true;
      }

      dsRenderIndex += 1;
      dsIndex += 1;
    }

    if (hasChanges) {
      scheduleMicrotask(() {
        notifyListeners();
      });
    }

    _lastCheckedGroupingIndex = dsRenderIndex - 1;
  }
}

typedef Widget? BuildBodyRowFunc(BuildContext context, TableViewController controller, int viewType, int renderIndex);
typedef Widget? BuildBodyCellFunc(BuildContext context, TableColumn col, TableViewController controller, int index);
typedef Widget? BuildHeaderCellFunc(BuildContext context, TableColumn col, TableViewController controller);

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
  final TableViewDataSource dataSource;
  BuildBodyRowFunc? buildBodyRowFunc;
  final String? emptyText;

  TableView(
      {Key? key,
      required this.columns,
      double? headerDividerWidth,
      this.headerDividerColor,
      TableViewController? controller,
      this.buildBodyRowFunc,
      this.emptyText,
      required this.dataSource})
      : super(key: key) {
    this.headerDividerWidth = headerDividerWidth ?? 2;
    this.controller = controller ?? TableViewController();
    this.controller._dataSource = this.dataSource;
  }

  @override
  State<StatefulWidget> createState() {
    return _TableViewState();
  }
}

class _TableViewState extends State<TableView> {
  final columnWidths = HashMap<TableColumn, double>();
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
      initialData: TableViewDataSource.STATE_LOADING,
      stream: widget.dataSource.stateChanged,
      builder: (context, snapshot) {
        print("snapshot ${snapshot.data}");

        switch (snapshot.data) {
          case TableViewDataSource.STATE_LOADING:
            return Center(
              child: CircularProgressIndicator(),
            );
          case TableViewDataSource.STATE_ERROR:
            return Center(
              child: Text("Error loading data"),
            );
          case TableViewDataSource.STATE_READY:
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
                controller: widget.controller._scrollController,
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
  }

  List<Widget> _buildHeaders(BuildContext ctx) {
    final List<Widget> widgets = [];

    final cols = this.widget.columns;
    for (int i = 0; i < cols.length; i++) {
      final col = cols[i];
      final isLast = cols.indexOf(col) == cols.length - 1;

      final colWidget = Container(
        alignment: col.contentAlignment ?? Alignment.centerLeft,
        width: columnWidths[col],
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
          double width = columnWidths[col]!;
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
        return bodyRow;

      default:
        return Container();
    }
  }
}
