import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
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
  Future<ApiResponse<http.ByteStream>> _execRequest(ApiRequestBuilder reqBuilder) async {
    try {
      final req = await reqBuilder.request();
      print("API REQUEST [${req.method}]${req.url}");
      final resp = await req.send();
      if (resp.statusCode == 200) {
        return ApiResponse.success(resp.stream);
      }
      return ApiResponse.failure("bad request", resp.statusCode);
    } catch (e) {
      return ApiResponse.failure("unexpected api error");
    }
  }

  Future<ApiResponse<List<SchemaVersion>>> schemaVersions(UserAccount account) async {
    final req = ApiRequestBuilder(HttpMethod.GET, "collections/revisions").forAccount(account);
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

  Future<ApiResponse<List<RemoteSchemaChangeset>>> changes(UserAccount account, List<SchemaVersion> versions) async {
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

    final req = ApiRequestBuilder(HttpMethod.GET, "collections/import").forAccount(account).addQueryParams(params);
    final resp = await _execRequest(req);

    final ApiResponse<List<RemoteSchemaChangeset>> x = await resp.map((body) async {
      List<RemoteSchemaChangeset> res = [];
      final rawJson = await body.bytesToString();
      final Map<String, dynamic> respBody = json.decode(rawJson);

      for (var key in respBody.keys) {
        res.add(RemoteSchemaChangeset.fromResponseJson(key, respBody[key]));
      }

      return res;
    });

    return x;
  }
}

enum HttpMethod { GET, POST, PUT, DELETE }

class ApiRequestBuilder {
  late final String _method;
  Object? _body;
  String _path;
  Map<String, String>? _qsParams;
  UserAccount? _userAccount;
  Map<String, String> _headers = {"Accept": "application/json"};

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
  }

  ApiRequestBuilder forAccount(UserAccount account) {
    _userAccount = account;
    return this;
  }

  ApiRequestBuilder addQueryParams(Map<String, String> params) {
    if (_qsParams == null) {
      _qsParams = HashMap();
    }
    _qsParams!.addAll(params);
    return this;
  }

  bool hasHeader(String key) {
    return _headers.containsKey(key);
  }

  ApiRequestBuilder addHeaders(Map<String, String> params) {
    _headers.addAll(params);
    return this;
  }

  ApiRequestBuilder body(Map<String, dynamic> body) {
    _body = body;
    return this;
  }

  Future<http.Request> request() async {
    final account = _userAccount;
    if (account != null) {
      await account.sign(this);
    }

    final url = ApiRequestBuilder.getUri(_path, _qsParams);

    final req = http.Request(_method, url);

    if (_body != null) {
      req.body = jsonEncode(_body);
    }

    req.headers.addAll(_headers);

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

class UserAccount {
  int id;
  String email;
  String password;

  static UserAccount current = UserAccount(id: 649, email: "bonnie@vagabondvending.com", password: "bonnierocks");

  UserAccount({required this.id, required this.email, required this.password});

  UserAccount.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        email = json['email'],
        password = json['password'];

  Map<String, dynamic> toJson() => {
        "id": id,
        "email": email,
        "password": password,
      };

  sign(ApiRequestBuilder req) {
    final xdate = DateTime.now().millisecondsSinceEpoch.toString();
    final toSign = "$password$xdate";
    final encoded = md5.convert(utf8.encode(toSign)).toString();
    final authToken = "$email:$encoded";

    final authHeaderName = "XAUTHENTICATION";
    if (!req.hasHeader(authHeaderName)) {
      req.addHeaders({
        authHeaderName: authToken,
        "XDATE": xdate,
      });
    }
  }
}
