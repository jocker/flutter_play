import 'dart:collection';

import 'package:vgbnd/ext.dart';

class SqlSelectQueryBuilder {
  final String _from;

  SqlSelectQueryBuilder(this._from);

  final _fieldsMap = new LinkedHashMap<String, String>();
  List<_SqlStringWithArgs>? _wheres;
  List<_SqlStringWithArgs>? _groupBy;
  List<_SqlStringWithArgs>? _joins;
  List<_SqlStringWithArgs>? _orders;
  int? _limit;
  int? _offset;

  Map<String, String> fieldMap() {
    return Map.from(_fieldsMap);
  }

  field(String selector, [String? alias]) {
    alias ??= selector;
    _fieldsMap[alias] = selector;
  }

  where(String sql, [List<Object>? args]) {
    (_wheres ??= []).add(_SqlStringWithArgs(sql, args: args));
  }

  join(String sql, [List<Object>? args]) {
    (_joins ??= []).add(_SqlStringWithArgs(sql, args: args));
  }

  order(String sql, [List<Object>? args]) {
    (_orders ??= []).add(_SqlStringWithArgs(sql, args: args));
  }

  groupBy(String sql, [List<Object>? args]) {
    (_groupBy ??= []).add(_SqlStringWithArgs(sql, args: args));
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
    c._groupBy = _groupBy?.toList(growable: true);
    c._fieldsMap.addAll(_fieldsMap);
    c._orders = _orders?.toList(growable: true);
    c._limit = _limit;
    c._offset = _offset;

    return c;
  }

  SqlSelectQueryBuilder forSnapshot(String snapshotTableName) {
    final c = SqlSelectQueryBuilder(snapshotTableName);
    for (final v in _fieldsMap.keys) {
      c._fieldsMap[v] = v;
    }
    return c;
  }

  SqlSelectQuery build() {
    final buf = StringBuffer("select ");
    final fieldNames = _fieldsMap.keys.toList();
    if (fieldNames.isEmpty) {
      buf.write("*");
    } else {
      for (int i = 0; i < fieldNames.length; i++) {
        if (i > 0) {
          buf.write(", ");
        }
        buf..write(_fieldsMap[fieldNames[i]])..write(" as ")..write(fieldNames[i]);
      }
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

    final groupings = _groupBy ?? List.empty(growable: false);
    var isFirstGrouping = true;
    for (final grouping in groupings) {
      if (isFirstGrouping) {
        isFirstGrouping = false;
        buf.write(" group by by ");
      } else {
        buf.write(", ");
      }

      grouping._writeTo(buf, args);
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

    final limit = _limit;
    final offset = _offset;
    if (limit != null && offset != null) {
      buf.write(" limit $limit offset $offset");
    }

    return SqlSelectQuery(buf.toString(), args: args);
  }

  bool get isOrdered {
    return _orders != null;
  }
}

class SqlSelectQuery extends _SqlStringWithArgs {
  static SqlSelectQuery fromJson(Map<String, dynamic> src) {
    return SqlSelectQuery(src["sql"], args: src["args"]);
  }

  SqlSelectQuery(String sql, {List<Object>? args}) : super(sql, args: args);

  static SqlSelectQueryBuilder from(String from) {
    return SqlSelectQueryBuilder(from);
  }

  Map<String, dynamic> toJson() {
    return {
      "sql": this.sql,
      "args": this.args,
    };
  }

  String signature() {
    return md5Digest(this.sql + (this.args?.join("&") ?? ""));
  }
}

class _SqlStringWithArgs {
  final String sql;
  final List<Object>? args;

  _SqlStringWithArgs(this.sql, {this.args});

  _writeTo(StringBuffer buf, List<Object> args) {
    buf.write(sql);
    if (this.args != null) {
      args.addAll(this.args!);
    }
  }
}
