import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/sync/schema.dart';

import 'net_connectivity_info.dart';

class RemoteRepository {
  final Api _api = Api();
  final UserAccount _userAccount;
  final NetConnectivityInfo _connectivityInfo;
  bool _isDisposed = false;

  RemoteRepository(this._userAccount, this._connectivityInfo);

  Future<Result<List<SchemaVersion>>> schemaVersions() async {
    return _api.schemaVersions(_userAccount);
  }

  Future<Result<List<RemoteSchemaChangeset>>> changes(List<SchemaVersion> versions, {bool? includeDeleted}) {
    return _api.changes(_userAccount, versions);
  }

  bool get isAvailable {
    return _connectivityInfo.networkingEnabled;
  }

  dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
    }
  }
}
