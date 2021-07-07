import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uri/uri.dart';
import 'package:vgbnd/sync/schema.dart';

class ApiResponse<T> {
  static ApiResponse<T> success<T>(T body) {
    return ApiResponse(body, 200, null);
  }

  static ApiResponse<T> failure<T>(String message, [int statusCode = -1]) {
    return ApiResponse(null, statusCode, message);
  }

  final T? body;
  final int statusCode;
  final String? errorMessage;

  bool get isSuccess {
    return this.statusCode == 200;
  }

  ApiResponse(this.body, this.statusCode, this.errorMessage);

  map<Q>(Future<Q> Function(T body) mapFn) async {
    Q? body;
    if (this.isSuccess && this.body != null) {
      body = await mapFn(this.body!);
    }
    return ApiResponse(body, statusCode, errorMessage);
  }
}

class Api {
  Future<ApiResponse<http.ByteStream>> _execRequest(http.Request req) async {
    try {
      final resp = await req.send();
      if (resp.statusCode == 200) {
        return ApiResponse.success(resp.stream);
      }
      return ApiResponse.failure("bad request", resp.statusCode);
    } catch (e) {
      return ApiResponse.failure("unexpected api error");
    }
  }

  Future<ApiResponse<List<SchemaVersion>>> schemaVersions() async {
    final req = ApiRequestBuilder(HttpMethod.GET, "collections/revisions").request();
    final resp = await _execRequest(req);
    final x = await resp.map<List<SchemaVersion>>((body) async {
      final List<SchemaVersion> revs = [];
      final rawJson = await body.bytesToString();
      final Map x = json.decode(rawJson);

      x.forEach((schemaName, value) {
        if (SyncDbSchema.isRegisteredSchema(schemaName)) {
          final revNum = DateTime.tryParse(value)?.millisecondsSinceEpoch;
          if (revNum != null) {
            revs.add(SchemaVersion(schemaName, revNum));
          }
        }
      });

      return revs;
    });

    return x;
  }

  Future<ApiResponse<List<RemoteSchemaChangeset>>> changes(List<SchemaVersion> versions) async {
    if (versions.isEmpty) {
      return ApiResponse.success(List.empty());
    }

    final params = {
      "raw": "true",
      "mode": "rows",
    };

    for (var version in versions) {
      params["since[${version.schemaName}]"] = version.revNum.toString();
    }

    final resp = await ApiRequestBuilder(HttpMethod.GET, "collections/import").addQueryParams(params).request().send();

    if (resp.statusCode == 200) {
      List<RemoteSchemaChangeset> res = [];

      final rawJson = await resp.stream.bytesToString();
      final Map<String, dynamic> respBody = json.decode(rawJson);

      for (var key in respBody.keys) {
        res.add(RemoteSchemaChangeset.fromResponseJson(key, respBody[key]));
      }

      return ApiResponse.success(res);
    }

    return ApiResponse.failure("", resp.statusCode);
  }
}

enum HttpMethod { GET, POST, PUT, DELETE }

class ApiRequestBuilder {
  late final String _method;
  Object? _body;
  String _path;
  Map<String, String>? _qsParams;
  Map<String, String>? _headers;

  //static final _baseApiUri = 'https://apim.vagabondvending.com/api/public';

  static final _baseApiUri = 'http://192.168.100.152:3000/api/public';

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
      "XAUTHENTICATION": "bonnie@vagabondvending.com:0a7e2fa2b51922cf327764147fe63afc",
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

class RemoteSchemaChangeset {
  static fromResponseJson(String collectionName, Map<String, dynamic> json) {
    List<String> columns = (json['headers'] as List<dynamic>).cast<String>();
    final data = (json['data'] as List<dynamic>);

    return RemoteSchemaChangeset(collectionName, columns, data);
  }

  final String collectionName;
  final List<String> remoteColumnNames;
  final List<dynamic> data;

  RemoteSchemaChangeset(this.collectionName, this.remoteColumnNames, this.data);
}
