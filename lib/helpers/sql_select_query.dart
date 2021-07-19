import 'dart:collection';

import 'package:vgbnd/data/sql_result_set.dart';
import 'package:vgbnd/sync/sync.dart';

class _SqlStringWithArgs {
  final String sql;
  final List<Object>? args;

  _SqlStringWithArgs(this.sql, this.args);

  _writeTo(StringBuffer buf, List<Object> args) {
    buf.write(sql);
    if (this.args != null) {
      args.addAll(this.args!);
    }
  }
}

class SqlSelectQueryBuilder {
  final String _from;

  SqlSelectQueryBuilder(this._from);

  final _fieldsMap = new LinkedHashMap<String, String>();
  List<_SqlStringWithArgs>? _wheres;
  List<_SqlStringWithArgs>? _joins;
  List<_SqlStringWithArgs>? _orders;
  int? _limit;
  int? _offset;

  Map<String, String> fieldMap(){
    return Map.from(_fieldsMap);
  }

  field(String selector, String alias) {
    _fieldsMap[alias] = selector;
  }

  where(String sql, [List<Object>? args]) {
    (_wheres ??= []).add(_SqlStringWithArgs(sql, args));
  }

  join(String sql, [List<Object>? args]) {
    (_joins ??= []).add(_SqlStringWithArgs(sql, args));
  }

  order(String sql, [List<Object>? args]) {
    (_orders ??= []).add(_SqlStringWithArgs(sql, args));
  }

  limit(int limit) {
    _limit = limit;
  }

  offset(int offset) {
    _offset = offset;
  }

  SqlSelectQueryBuilder clone() {
    final c = SqlSelectQueryBuilder(this._from);
    c._wheres = _wheres?.toList(growable: true);
    c._joins = _joins?.toList(growable: true);
    c._fieldsMap.addAll(_fieldsMap);

    return c;
  }

  SqlSelectQuery build() {
    final buf = StringBuffer("select ");
    final fieldNames = _fieldsMap.keys.toList();
    for (int i = 0; i < fieldNames.length; i++) {
      if (i > 0) {
        buf.write(", ");
      }
      buf..write(_fieldsMap[fieldNames[i]])..write(" as ")..write(fieldNames[i]);
    }
    buf..write(" from ")..write(_from);
    final List<Object> args = [];

    final joins = _joins ?? List.empty(growable: false);
    for (final join in joins) {
      buf.write(" ");
      join._writeTo(buf, args);
    }

    final wheres = _wheres ?? List.empty(growable: false);
    var isFirstWhere = true;
    for (final where in wheres) {
      buf.write(" ");
      if (isFirstWhere) {
        isFirstWhere = false;
        buf.write(" where ");
      } else {
        buf.write(" and ");
      }

      where._writeTo(buf, args);
    }

    final orders = _orders ?? List.empty(growable: false);
    var isFirstOrder = true;
    for (final order in orders) {
      if (isFirstOrder) {
        isFirstOrder = false;
        buf.write(" order by ");
      } else {
        buf.write(", ");
      }

      order._writeTo(buf, args);
    }

    return SqlSelectQuery(buf.toString(), args: args);
  }

  bool get isOrdered {
    return _orders != null;
  }
}

class SqlSelectQuery {
  static SqlSelectQueryBuilder from(String from) {
    return SqlSelectQueryBuilder(from);
  }

  final String sql;
  final List<Object>? args;

  SqlSelectQuery(this.sql, {this.args});

  Future<SqlResultSet> run() async {
    return await SyncEngine.current().select(this.sql, args: this.args);
  }
}
