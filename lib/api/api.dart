import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uri/uri.dart';
import 'package:vgbnd/ext.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';

class Result<T> {
  static Result<T> success<T>(T body) {
    return Result(body, 200, null);
  }

  static Result<T> failure<T>(String message, [int statusCode = -1]) {
    return Result(null, statusCode, message);
  }

  final T? body;
  final int statusCode;
  final String? errorMessage;

  bool get isSuccess {
    return this.statusCode == 200;
  }

  Result(this.body, this.statusCode, this.errorMessage);

  map<Q>(Future<Q> Function(T body) mapFn) async {
    Q? body;
    if (this.isSuccess && this.body != null) {
      body = await mapFn(this.body!);
    }
    return Result(body, statusCode, errorMessage);
  }
}

class Api {
  UserAccount? _account;

  Api(this._account);

  Future<Result<http.ByteStream>> _execRequest(ApiRequestBuilder reqBuilder) async {
    try {
      final req = await reqBuilder.request();
      print("API REQUEST [${req.method}]${req.url}");
      final resp = await req.send();
      if (resp.statusCode == 200) {
        return Result.success(resp.stream);
      }
      return Result.failure("bad request", resp.statusCode);
    } catch (e) {
      return Result.failure("unexpected api error");
    }
  }

  Future<Result<List<SchemaVersion>>> schemaVersions() async {
    final req = ApiRequestBuilder(HttpMethod.GET, "collections/revisions").forAccount(_account);
    final resp = await _execRequest(req);
    final x = await resp.map<List<SchemaVersion>>((body) async {
      final List<SchemaVersion> revs = [];
      final rawJson = await body.bytesToString();
      final Map x = json.decode(rawJson);

      x.forEach((schemaName, value) {
        if (SyncSchema.isRegisteredSchema(schemaName)) {
          final revNum = SyncSchema.parseRevNum(value);
          if (revNum != null) {
            revs.add(SchemaVersion(schemaName, revNum));
          }
        }
      });

      return revs;
    });

    return x;
  }

  Future<Result<List<RemoteSchemaChangelog>>> changes(List<SchemaVersion> versions, {bool? includeDeleted}) async {
    if (versions.isEmpty) {
      return Result.success(List.empty());
    }

    final Map<String, String> queryParams = {};

    for (var version in versions) {
      queryParams["since[${version.schemaName}]"] = version.revNum.toString();
    }

    return _makeRequestForChangeset(HttpMethod.GET, "collections/import",
        queryParams: queryParams, includeDeleted: includeDeleted);
  }

  Future<Result<List<RemoteSchemaChangelog>>> updateSchemaObject(String schemaName, int id, Object values) async {
    return await _makeRequestForChangeset(HttpMethod.PUT, "collections/$schemaName/$id", payload: {"data": values});
  }

  Future<Result<List<RemoteSchemaChangelog>>> createSchemaObject(String schemaName, Map<String, dynamic> values) async {
    return await _makeRequestForChangeset(HttpMethod.POST, "collections/$schemaName", payload: {"data": values});
  }

  Future<Result<List<RemoteSchemaChangelog>>> deleteSchemaObject(String schemaName, int objectId) async {
    return await _makeRequestForChangeset(HttpMethod.DELETE, "collections/$schemaName/$objectId");
  }

  Future<Result<List<RemoteSchemaChangelog>>> postRequestForChangeset(String urlPath, Object payload,
      {Map<String, String>? queryParams}) {
    return _makeRequestForChangeset(HttpMethod.POST, urlPath,
        payload: payload, includeDeleted: true, queryParams: queryParams);
  }

  Future<Result<List<RemoteSchemaChangelog>>> makeRequestForChangeset(
      {required HttpMethod httpMethod, required String urlPath, Object? payload, Map<String, String>? queryParams}) {
    return _makeRequestForChangeset(httpMethod, urlPath,
        payload: payload, includeDeleted: true, queryParams: queryParams);
  }

  Future<Result<List<RemoteSchemaChangelog>>> _makeRequestForChangeset(HttpMethod httpMethod, String urlPath,
      {Object? payload, bool? includeDeleted, Map<String, String>? queryParams}) async {
    var reqQp = {
      "mode": "rows",
      "raw": "true",
      "include_deleted": "true",
    };

    if (includeDeleted != null) {
      reqQp["include_deleted"] = includeDeleted ? "true" : "false";
    }

    if (queryParams != null) {
      for (var k in queryParams.keys) {
        reqQp[k] = queryParams[k]!;
      }
    }

    final req = ApiRequestBuilder(httpMethod, urlPath).addQueryParams(reqQp).forAccount(_account).body(payload);
    final resp = await _execRequest(req);

    final Result<List<RemoteSchemaChangelog>> changesetResp = await resp.map((body) async {
      List<RemoteSchemaChangelog> res = [];
      final rawJson = await body.bytesToString();
      final Map<String, dynamic> respBody = json.decode(rawJson);

      for (var key in respBody.keys) {
        res.add(RemoteSchemaChangelog.fromResponseJson(key, respBody[key]));
      }

      return res;
    });

    return changesetResp;
  }
}

enum HttpMethod { GET, POST, PUT, DELETE }

class ApiRequestBuilder {
  late final String _method;
  Object? _body;
  String _path;
  Map<String, String>? _qsParams;
  UserAccount? _userAccount;
  Map<String, String> _headers = {"Accept": "application/json", "Content-Type": "application/json"};

  //static final _baseApiUri = 'https://apim.vagabondvending.com/api/public';

  static final _baseApiUri = 'http://192.168.100.152:3000/api/public';

  Uri _getApiUri(String path, [Map<String, String>? qsParams]) {
    if (path.startsWith("/")) {
      path = path.substring(1);
    }
    
    final _baseApiUri = (_userAccount?.env ?? AppEnvironment.Production).endpoint;

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
  }

  ApiRequestBuilder forAccount(UserAccount? account) {
    _userAccount = account;
    return this;
  }

  ApiRequestBuilder addQueryParams(Map<String, String>? params) {
    if (params != null) {
      if (_qsParams == null) {
        _qsParams = HashMap();
      }
      _qsParams!.addAll(params);
    }
    return this;
  }

  bool hasHeader(String key) {
    return _headers.containsKey(key);
  }

  ApiRequestBuilder addHeaders(Map<String, String> params) {
    _headers.addAll(params);
    return this;
  }

  ApiRequestBuilder body(Object? body) {
    _body = body;
    return this;
  }

  Future<http.Request> request() async {
    final account = _userAccount;
    if (account   != null) {
      await account.sign(this);
    }

    final url = _getApiUri(_path, _qsParams);

    final req = http.Request(_method, url);

    if (_body != null) {
      req.body = jsonEncode(_body);
    }

    req.headers.addAll(_headers);

    return req;
  }
}

class RemoteSchemaChangelog {
  static empty(String schemaName) {
    return RemoteSchemaChangelog(schemaName, [], []);
  }

  static fromResponseJson(String schemaName, Map<String, dynamic> json) {
    List<String> columns = (json['headers'] as List<dynamic>).cast<String>();
    final data = (json['data'] as List<dynamic>);

    return RemoteSchemaChangelog(schemaName, columns, data);
  }

  final String schemaName;
  final List<String> remoteColumnNames;
  final List<dynamic> rawData;

  _RemoteSchemaChangelogSpec? _internalSpec;

  RemoteSchemaChangelog(this.schemaName, this.remoteColumnNames, this.rawData);

  List<String> get schemaAttributeNames {
    return _spec().schemaAttributeNames;
  }

  _RemoteSchemaChangelogSpec _spec() {
    final x = _internalSpec;
    if (x != null) {
      return x;
    }

    final schema = SyncSchema.byName(this.schemaName);
    List<String> localColumnNames = schema?.remoteReadableColumns.map((e) => e.name).toList() ?? List.empty();
    var deletedColIndex = -1;
    var idColIndex = -1;
    var remoteColIndex = -1;
    var remoteRevisionDateColIndex = -1;

    List<String> schemaAttributeNames = [];
    List<int> remoteValueIndices = [];
    for (var key in this.remoteColumnNames) {
      remoteColIndex += 1;
      if (deletedColIndex < 0 && key == SyncSchema.REMOTE_COL_DELETED) {
        deletedColIndex = remoteColIndex;
        continue;
      }

      if (remoteRevisionDateColIndex < 0 && key == SyncSchema.REMOTE_COL_REVISION_DATE) {
        remoteRevisionDateColIndex = remoteColIndex;
        continue;
      }

      if (idColIndex < 0 && key == SyncSchema.REMOTE_COL_ID) {
        idColIndex = remoteColIndex;
      }

      final colIdx = localColumnNames.indexOf(key);
      if (colIdx < 0) {
        continue;
      }
      schemaAttributeNames.add(key);
      remoteValueIndices.add(remoteColIndex);
    }

    _internalSpec = _RemoteSchemaChangelogSpec(
        idColIndex, remoteRevisionDateColIndex, deletedColIndex, schemaAttributeNames, remoteValueIndices);
    return this._spec();
  }

  Iterable<RemoteSchemaChangelogEntry> entries() sync* {
    final deletedValues = HashSet.from([1, 'true', true]);

    bool? recDeleted;
    int? recRevNum;
    String? recId;

    int index = 0;

    final spec = this._spec();

    for (dynamic raw in this.rawData) {
      recDeleted = null;
      recRevNum = null;
      recId = null;

      final row = raw.cast<Object?>();

      if (spec.deletedColIndex >= 0) {
        recDeleted = deletedValues.contains(row[spec.deletedColIndex]);
      }

      if (spec.remoteRevisionDateColIndex >= 0) {
        recRevNum = SyncSchema.parseRevNum(row[spec.remoteRevisionDateColIndex]);
      }

      if (spec.idColIndex >= 0) {
        final rawId = row[spec.idColIndex];
        if (rawId is int) {
          recId = rawId.toString();
        } else if (rawId is String) {
          recId = rawId;
        }
      }

      yield RemoteSchemaChangelogEntry(this, index, recId, recRevNum, recDeleted);

      index += 1;
    }
  }
}

class _RemoteSchemaChangelogSpec {
  final int idColIndex;
  final int remoteRevisionDateColIndex;
  final int deletedColIndex;

  final List<String> schemaAttributeNames;
  final List<int> remoteValueIndices;

  _RemoteSchemaChangelogSpec(this.idColIndex, this.remoteRevisionDateColIndex, this.deletedColIndex,
      this.schemaAttributeNames, this.remoteValueIndices);
}

class RemoteSchemaChangelogEntry {
  final RemoteSchemaChangelog _owner;
  final int index;
  final int? revisionNum;
  final bool? isDeleted;
  final String? id;

  int? get numericId {
    if (id == null) {
      return null;
    }
    return int.tryParse(id!);
  }

  RemoteSchemaChangelogEntry(this._owner, this.index, this.id, this.revisionNum, this.isDeleted);

  List<Object?> get rawValues {
    final item = this._owner.rawData[this.index];
    return item.cast<Object?>();
  }

  List<Object?> get schemaValues {
    final s = _owner._spec();
    final raw = s.schemaAttributeNames;
    final List<Object?> res = [];

    for (var idx in s.remoteValueIndices) {
      res.add(raw[idx]);
    }

    return res;
  }

  bool putSchemaValues(List<Object?> dest) {
    final s = _owner._spec();
    final row = this.rawValues;
    for (var idx = 0; idx < s.remoteValueIndices.length; idx += 1) {
      final value = row[s.remoteValueIndices[idx]];
      if (idx < dest.length) {
        dest[idx] = value;
      } else {
        dest.add(value);
      }
    }
    return true;
  }

  Map<String, dynamic> toMap() {
    final row = this.rawValues;
    final Map<String, dynamic> objData = {};
    for (var idx = 0; idx < _owner.remoteColumnNames.length; idx++) {
      objData[_owner.remoteColumnNames[idx]] = row[idx];
    }

    return objData;
  }

  SyncObject? toSyncObject() {
    final schema = SyncSchema.byName(_owner.schemaName);
    if (schema != null) {
      return schema.instantiate(toMap());
    }
  }
}

class AppEnvironment {
  final String key;
  final String endpoint;

  static const AppEnvironment Test =
          AppEnvironment(key: "test", endpoint: "http://testapi.appenv.vagabondvending.com/api/public"),
      Staging = AppEnvironment(key: "staging", endpoint: "http://stageapi.appenv.vagabondvending.com/api/public"),
      Demo = AppEnvironment(key: "demo", endpoint: "http://demoapi.appenv.vagabondvending.com/api/public"),
      Production = AppEnvironment(key: "production", endpoint: "http://apim.vagabondvending.com/api/public"),
      Local = AppEnvironment(key: "local", endpoint: "http://192.168.100.152:3000/api/public");

  static const _ALL = [Test, Staging, Demo, Production, Local];

  static AppEnvironment? byKey(String key) {
    for (final env in _ALL) {
      if (env.key == key) {
        return env;
      }
    }
    return null;
  }

  const AppEnvironment({required this.key, required this.endpoint});
}

class UserAccount {
  final int id;
  final String email;
  final String password;
  final String displayName;
  final String envName;

  UserAccount(
      {required this.id,
      required this.email,
      required this.password,
      required this.displayName,
      required this.envName});

  UserAccount.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        email = json['email'],
        password = json['pwd'],
        displayName = json['display_name'],
        envName = json['env'] ?? AppEnvironment.Production.key;

  Map<String, dynamic> toJson() => {
        "id": id,
        "email": email,
        "pwd": password,
        "display_name": displayName,
        "env": envName,
      };

  sign(ApiRequestBuilder req) {
    final xdate = DateTime.now().millisecondsSinceEpoch.toString();
    final toSign = "$password$xdate";
    final encoded = md5Digest(toSign);
    final authToken = "$email:$encoded";

    final authHeaderName = "XAUTHENTICATION";
    if (!req.hasHeader(authHeaderName)) {
      req.addHeaders({
        authHeaderName: authToken,
        "XDATE": xdate,
      });
    }
  }

  AppEnvironment get env {
    return AppEnvironment.byKey(this.envName) ?? AppEnvironment.Production;
  }
}
