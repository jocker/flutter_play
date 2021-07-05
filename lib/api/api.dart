import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uri/uri.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/models/coil.dart';

class RemoteRevision {
  String name;
  DateTime date;

  RemoteRevision(this.name, this.date);
}

class Api {
  revisions() async {
    try {
      final resp =
          await ApiRequestBuilder(HttpMethod.GET, "collections/revisions")
              .request()
              .send();
      if (resp.statusCode == 200) {
        final rawJson = await resp.stream.bytesToString();
        final Map x = json.decode(rawJson);

        x.forEach((key, value) {
          final x = DateTime.parse(value);
          print(x);
        });
        print("done");
      }
    } catch (e) {
      print("err");
    }
  }

  Future<List<RemoteCollectionChangeset>> changes(DbConn db) async {
    final params = {
      "since[locations]": "0",
      "raw": "true",
      "mode": "rows",
    };

    List<RemoteCollectionChangeset> res = [];

    final resp = await ApiRequestBuilder(HttpMethod.GET, "collections/import")
        .addQueryParams(params)
        .request()
        .send();

    if (resp.statusCode == 200) {
      final rawJson = await resp.stream.bytesToString();
      final Map<String, dynamic> respBody = json.decode(rawJson);

      for (var key in respBody.keys) {
        res.add(RemoteCollectionChangeset.fromResponseJson(key, respBody[key]));
      }
    }

    for (var col in res) {
      await col.save(db);
    }

    return res;
  }
}

enum HttpMethod { GET, POST, PUT, DELETE }

class ApiRequestBuilder {
  late final String _method;
  Object? _body;
  String _path;
  Map<String, String>? _qsParams;
  Map<String, String>? _headers;

  static final _baseApiUri = 'https://apim.vagabondvending.com/api/public';

  //static final _baseApiUri = 'http://192.168.100.152:3000/api/public';

  static Uri getUri(String path, [Map<String, String>? qsParams]) {
    if (path.startsWith("/")) {
      path = path.substring(1);
    }

    var u = Uri.parse("$_baseApiUri/$path");
    if (qsParams != null) {
      final b = UriBuilder.fromUri(u)
        ..queryParameters = qsParams
        ..build();

      u = b.build();
    }

    return u;
  }

  ApiRequestBuilder(HttpMethod method, this._path) {
    switch (method) {
      case HttpMethod.POST:
        _method = "POST";
        break;
      case HttpMethod.GET:
        _method = "GET";
        break;
      case HttpMethod.PUT:
        _method = "PUT";
        break;
      case HttpMethod.DELETE:
        _method = "DELETE";
        break;
    }
    addHeaders({
      "XAUTHENTICATION":
          "bonnie@vagabondvending.com:0a7e2fa2b51922cf327764147fe63afc",
      "Accept": "application/json"
    });
  }

  ApiRequestBuilder addQueryParams(Map<String, String> params) {
    if (_qsParams == null) {
      _qsParams = HashMap();
    }
    _qsParams!.addAll(params);
    return this;
  }

  ApiRequestBuilder addHeaders(Map<String, String> params) {
    if (_headers == null) {
      _headers = HashMap();
    }
    _headers!.addAll(params);
    return this;
  }

  ApiRequestBuilder body(Map<String, dynamic> body) {
    _body = body;
    return this;
  }

  http.Request request() {
    final url = ApiRequestBuilder.getUri(_path, _qsParams);

    final req = http.Request(_method, url);

    if (_body != null) {
      req.body = jsonEncode(_body);
    }

    if (_headers != null) {
      req.headers.addAll(_headers!);
    }

    return req;
  }
}

class RemoteCollectionChangeset {
  static fromResponseJson(String collectionName, Map<String, dynamic> json) {
    List<String> columns = (json['headers'] as List<dynamic>).cast<String>();
    final data = (json['data'] as List<dynamic>);

    return RemoteCollectionChangeset(collectionName, columns, data);
  }

  final String collectionName;
  final List<String> remoteColumnNames;
  final List<dynamic> data;

  RemoteCollectionChangeset(
      this.collectionName, this.remoteColumnNames, this.data);

  save(SyncDbCollection collection, DbConn db) async {
    final tmpTableName = "${this.collectionName}_tmp";
    db.execute(
        "create temporary table $tmpTableName as select * from $collectionName where false");

    List<String> localColumnNames = collection.remoteReadableColumns.map((e) => e.name).toList();

    var deletedColIndex = -1;
    var idColIndex = -1;
    var remoteColIndex = -1;
    List<String> affectedColumnNames = [];
    List<int> remoteValueIndices = [];
    for (var key in this.remoteColumnNames) {
      remoteColIndex += 1;
      if (deletedColIndex < 0 && key == "deleted") {
        deletedColIndex = remoteColIndex;
        continue;
      }
      if (idColIndex < 0 && key == "id") {
        idColIndex = remoteColIndex;
      }

      final colIdx = localColumnNames.indexOf(key);
      if (colIdx < 0) {
        continue;
      }
      affectedColumnNames.add(key);
      remoteValueIndices.add(colIdx);
    }

    final stm = db.prepare(
        "insert into $tmpTableName( ${affectedColumnNames.join(",")} ) values ( ${affectedColumnNames.map((e) => "?").join(",")} )");

    final args = List<Object?>.filled(affectedColumnNames.length, null);
    final deleteItemIds = Set<Object>();
    for (dynamic raw in this.data) {
      final row = raw.cast<Object?>();
      var idx = 0;
      for (var i in remoteValueIndices) {
        args[idx] = row[i];
        idx += 1;
      }

      if (idColIndex >= 0 && row[deletedColIndex] == true) {
        final id = row[idColIndex];
        deleteItemIds.add(id);
      }

      stm.execute(args);
    }

    print("done");
  }
}
/*
local: remote
 */

const LOCATION_COLUMN_MAPPING = {
  "id": "id",
  "name": "location_name",
  "address": "location_address",
  "address_secondary": "location_address2",
  "city": "location_city",
  "state": "location_state",
  "postal_code": "location_zip",
  "type": "location_type",
  "last_visit": "last_visit",
  "planogram_id": "planogram_id",
  "flags": "flags",
  "latitude": "lat",
  "longitude": "long",
  "account": "account",
  "route": "route",
  "make": "location_make",
  "model": "location_model",
  "serial": "machine_serial",
  "cardreader_serial": "cardreader_serial",
};
