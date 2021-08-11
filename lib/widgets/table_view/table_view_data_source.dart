import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/data/sql_result_set.dart';
import 'package:vgbnd/helpers/sql_select_query.dart';
import 'package:vgbnd/sync/sync.dart';

class SqlQueryDataSource extends TableViewDataSource<SqlRow> {
  SqlSelectQueryBuilder _baseQuery;
  late Map<String, String> _fieldSelectors;
  late final String? _textSearchSelector;
  late final int _pageSize;
  late final bool _useSnapshot;

  SqlQueryDataSource(this._baseQuery,
      {Map<String, String>? fieldSelectors, String? textSearchSelector, int? pageSize, bool? useSnapshot}) {
    this._pageSize = pageSize ?? 50;
    this._fieldSelectors = fieldSelectors ?? this._baseQuery.fieldMap();
    this._textSearchSelector = textSearchSelector;
    this._useSnapshot = useSnapshot ?? false;
    print("SqlQueryDataSource constructor");
  }

  @override
  TableViewDataProvider<SqlRow> initProvider(TableViewDataFilterCriteria criteria) {
    return SqlTableViewDataProvider(_buildQuery(criteria), this._pageSize);
  }

  String? _getFieldSelector(String aliasName) {
    return _fieldSelectors[aliasName] ?? aliasName;
  }

  @override
  Future prepare() async {
    if (_useSnapshot) {
      print("prepare ${this._baseQuery.build().sql}");
      this._baseQuery = await SyncEngine.current().createQuerySnapshot(this._baseQuery);
      this._fieldSelectors = this._baseQuery.fieldMap();
    }
  }

  SqlSelectQueryBuilder _buildQuery(TableViewDataFilterCriteria criteria) {
    final q = _baseQuery.clone();
    if (criteria.query != null && _textSearchSelector != null) {
      q.where('lower($_textSearchSelector) like ?', ["%${criteria.query}%"]);
    }

    if (criteria.where != null) {
      for (final fieldName in criteria.where!.keys) {
        final fieldSelector = _getFieldSelector(fieldName);
        q.where('$fieldSelector = ?', [criteria.where![fieldName]!]);
      }
    }
    if (criteria.sortBy != null) {
      for (final fieldName in criteria.sortBy!.keys) {
        final fieldSelector = _getFieldSelector(fieldName);
        String? dir;
        switch (criteria.sortBy![fieldName]) {
          case SortDirection.Asc:
            dir = "asc";
            break;
          case SortDirection.Desc:
            dir = "desc";
            break;
          default:
            break;
        }

        if (dir == null) {
          continue;
        }

        q.order("$fieldSelector $dir");
      }
    }

    return q;
  }
}

class SqlTableViewDataProvider extends TableViewDataProvider<SqlRow> {
  final SqlSelectQueryBuilder _sql;
  final int _pageSize;
  int _currentPage = 0;

  SqlTableViewDataProvider(this._sql, this._pageSize);

  @override
  Stream<DataProviderLoadResult<SqlRow>> next() {
    StreamController<DataProviderLoadResult<SqlRow>>? ctrl;
    ctrl = StreamController(
      onCancel: () {
        //TODO cancel query
      },
      onListen: () {
        scheduleMicrotask(() async {
          final q = (_sql.clone()
                ..limit(this._pageSize)
                ..offset(_currentPage * _pageSize))
              .build();

          final res = await SyncEngine.current().select(q.sql, args: q.args);
          _currentPage += 1;
          final rows = res.toList();

          final c = ctrl;
          if (c == null) {
            return;
          }
          ctrl = null;
          c.sink.add(DataProviderLoadResult(success: true, items: rows, hasMore: rows.length == _pageSize));
          await c.close();
        });
      },
    );

    return ctrl!.stream;
  }
}

abstract class TableViewDataSource<T> extends ChangeNotifier {
  static const STATE_NONE = 0,
      STATE_PREPARING = 1,
      STATE_PROVISIONING = 2,
      STATE_RELOADING = 3,
      STATE_LOADING_MORE = 4,
      STATE_IDLE = 5,
      STATE_ERROR = 6;

  final List<T> _loadedData = [];
  var _hasMoreToLoad = true;
  var _isDisposed = false;
  final int _loadAhead = 10;
  var _dataIsDirty = false;
  var _isPrepared = false;

  var _currentState = STATE_NONE;
  final List<VoidCallback> _reloadCallbacks = [];

  var _currentCriteria = TableViewDataFilterCriteria.empty();
  StreamSubscription? _loadSubscription;
  TableViewDataProvider<T>? _dataProvider;

  Timer? _reloadTimer;

  Stream<int>? _stateChanged;

  int get itemCount {
    return _loadedData.length;
  }

  bool get isFullyLoaded {
    return !_hasMoreToLoad;
  }

  bool get isItemCountApproximate {
    return _hasMoreToLoad;
  }

  bool get isEmpty {
    return !_hasMoreToLoad && itemCount == 0;
  }

  @protected
  TableViewDataProvider<T> initProvider(TableViewDataFilterCriteria criteria);

  _onBatchLoaded(DataProviderLoadResult<T> result) {
    final wasDirty = _dataIsDirty;
    if (_dataIsDirty) {
      _loadedData.clear();
      _dataIsDirty = false;
    }
    _loadedData.addAll(result.items);
    _hasMoreToLoad = result.hasMore;
    _setState(STATE_IDLE);
    if (wasDirty) {
      _reloadCallbacks.forEach((element) {
        element();
      });
      _reloadCallbacks.clear();
    }
  }

  setCriteria(TableViewDataFilterCriteria criteria) {
    if (criteria != _currentCriteria) {
      _currentCriteria = criteria;
      _reload();
    }
  }

  reload({bool? now, VoidCallback? callback}) {
    if (_isDisposed) {
      return;
    }
    if (callback != null) {
      _reloadCallbacks.add(callback);
    }
    now ??= false;
    _reloadTimer?.cancel();
    if (now) {
      _reload();
      return;
    }
    _reloadTimer = Timer(const Duration(milliseconds: 10), () {
      _reload();
    });
  }

  _reload() {
    print("reload");
    _reloadTimer?.cancel();
    _dataProvider?.dispose();
    _dataProvider = initProvider(_currentCriteria);
    _loadSubscription?.cancel();
    _loadSubscription = null;
    _dataIsDirty = true;

    _hasMoreToLoad = true;
    _setState(STATE_IDLE);
    notifyListeners();
    _triggerLoad();
  }

  @protected
  Future prepare() async {
    return;
  }

  bool _triggerLoad({bool? force}) {
    if (_isDisposed) {
      return false;
    }
    if (!_isPrepared) {
      if (_setState(STATE_PREPARING, prevStates: [STATE_NONE])) {
        scheduleMicrotask(() async {
          await prepare();
          _isPrepared = true;
          if (_setState(STATE_IDLE, prevStates: [STATE_PREPARING])) {
            _triggerLoad();
          }
        });
        return true;
      } else {
        return false;
      }
    }

    force ??= false;
    if (!_isPrepared) {
      force = false;
    }
    if (!force) {
      switch (_currentState) {
        case STATE_PREPARING:
        case STATE_RELOADING:
        case STATE_PROVISIONING:
        case STATE_LOADING_MORE:
          return false;
      }
      if (!_hasMoreToLoad) {
        return false;
      }
    }

    bool doLoad = false;

    if (_hasMoreToLoad) {
      final nextState = _dataIsDirty
          ? STATE_RELOADING
          : _loadedData.isEmpty
              ? STATE_PROVISIONING
              : STATE_LOADING_MORE;
      doLoad = _setState(nextState, prevStates: [STATE_IDLE]);
    }

    if (!doLoad) {
      return false;
    }

    print("triggerLoad");

    StreamSubscription? triggeredSub;
    _dataProvider ??= initProvider(TableViewDataFilterCriteria.empty());
    final provider = _dataProvider ?? initProvider(TableViewDataFilterCriteria.empty());

    triggeredSub = provider.next().listen((event) {
      triggeredSub?.cancel();
      if (_loadSubscription == triggeredSub) {
        _loadSubscription = null;
        _onBatchLoaded(event);
      }
    });

    _loadSubscription = triggeredSub;

    return true;
  }

  T? getItemAt(int pos) {
    if (_currentState == STATE_NONE) {
      _triggerLoad();
    }
    if (pos >= 0 && pos < itemCount) {
      return _loadedData[pos];
    }
    return null;
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    super.dispose();
    _loadSubscription?.cancel();
    _dataProvider?.dispose();
    _loadedData.clear();
    _reloadTimer?.cancel();
  }

  int get currentState {
    return _currentState;
  }

  Stream<int> get stateChanged {
    var prevState = _currentState;
    _stateChanged =
        _stateChanged ?? _createStream(() => prevState != _currentState, () => _currentState).asBroadcastStream();
    return _stateChanged!;
  }

  bool _setState(int newState, {List<int>? prevStates, bool? forceNotify}) {
    if (_isDisposed) {
      return false;
    }
    forceNotify ??= false;
    if (!forceNotify) {
      forceNotify = (_currentState != newState) && (prevStates == null || prevStates.contains(_currentState));
    }
    if (forceNotify) {
      print("changed from $_currentState to $newState}");
      _currentState = newState;
      notifyListeners();
      return true;
    }
    return false;
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
}

class TableViewDataFilterCriteria {
  static TableViewDataFilterCriteria empty() {
    return TableViewDataFilterCriteria();
  }

  final String? query;
  final Map<String, Object>? where;
  final Map<String, SortDirection>? sortBy;

  TableViewDataFilterCriteria({this.query, this.where, this.sortBy});

  TableViewDataFilterCriteria clone() {
    final where = this.where;
    final sortBy = this.sortBy;
    return TableViewDataFilterCriteria(
      query: this.query,
      where: where == null ? null : Map.of(where),
      sortBy: sortBy == null ? null : Map.of(sortBy),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableViewDataFilterCriteria &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          where == other.where &&
          sortBy == other.sortBy;

  @override
  int get hashCode => query.hashCode ^ where.hashCode ^ sortBy.hashCode;
}

abstract class TableViewDataProvider<T> {
  Stream<DataProviderLoadResult<T>> next();

  dispose() {}
}

class DataProviderLoadResult<T> {
  final Iterable<T> items;
  final bool hasMore;
  final bool success;

  DataProviderLoadResult({required this.success, required this.items, required this.hasMore});
}
