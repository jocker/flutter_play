import 'dart:async';
import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/widgets/table_view/table_view.dart';
import 'package:vgbnd/widgets/table_view/table_view_data_source.dart';

class TableViewController extends ChangeNotifier {
  static const int ITEM_VIEW_TYPE_DATASOURCE_ITEM = 0, ITEM_VIEW_TYPE_GROUP_HEADER = 1, ITEM_VIEW_TYPE_FAB_SPACER = 2;

  TableViewController({bool? addFabSpacer}) {
    if (addFabSpacer == true) {
      this.appendViewTypes.add(ITEM_VIEW_TYPE_FAB_SPACER);
    }
  }

  final List<int> appendViewTypes = [];
  final List<int> prependViewTypes = [];

  String? _groupingColumn;

  final List<int> _groupNamesViewTypeIndices = [];
  int _lastCheckedGroupingIndex = -1;
  int? _lastDataSourceRenderIndex;

  final _scrollController = ScrollController();
  SqlQueryDataSource? _dataSource;

  final _sortDirections = new HashMap<TableColumn, SortDirection>();
  StreamSubscription? _streamSub;

  int get renderItemCount {
    return datasourceCount + _groupNamesViewTypeIndices.length + appendViewTypes.length + prependViewTypes.length;
  }

  int get datasourceCount {
    return _dataSource?.itemCount ?? 0;
  }

  get scrollController => _scrollController;

  set dataSource(SqlQueryDataSource dataSource) {
    _dataSource = dataSource;
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
    final row = this._dataSource?.getItemAt(cursorIndex);

    if (row != null) {
      return row.getValueAt(columnName: columnName);
    }
    return null;
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
      _lastDataSourceRenderIndex = prependViewTypes.length + datasourceCount;
      return;
    }
    if (renderIndex < prependViewTypes.length) {
      return;
    }
    int dsRenderIndex = (renderIndex ~/ pageSize) * pageSize;
    if (dsRenderIndex < prependViewTypes.length) {
      dsRenderIndex = prependViewTypes.length;
    }
    final c = this._dataSource;
    if (c?.currentState != TableViewDataSource.STATE_IDLE) {
      return;
    }

    if (_groupNamesViewTypeIndices.isNotEmpty && dsRenderIndex < _groupNamesViewTypeIndices.last) {
      dsRenderIndex = _groupNamesViewTypeIndices.last;
    }
    int dsIndex = getDatasourceIndex(dsRenderIndex);
    if (dsIndex < 0) {
      return;
    }

    final endIndex = dsIndex + pageSize;
    if (c == null || c.getItemAt(dsIndex) == null) {
      return;
    }
    Object? prevColumnValue;
    bool hasChanges = false;

    while (dsIndex < endIndex) {

      if(dsIndex == c.itemCount-1 && !c.isFullyLoaded){
        return;
      }

      if (c.getItemAt(dsIndex) == null) {
        // reached the end of the data source
        if (c.isFullyLoaded) {
          _lastDataSourceRenderIndex = dsRenderIndex - 1;
        }

        break;
      }

      int viewType = TableViewController.ITEM_VIEW_TYPE_DATASOURCE_ITEM;
      if (dsIndex == 0) {
        _groupNamesViewTypeIndices.clear();
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
        if(_groupNamesViewTypeIndices.isEmpty || _groupNamesViewTypeIndices.last != dsRenderIndex){
          _groupNamesViewTypeIndices.add(dsRenderIndex);
        }

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
