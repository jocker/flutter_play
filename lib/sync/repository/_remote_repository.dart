import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/sync/schema.dart';

import '../net_connectivity_info.dart';

class RemoteRepository {
  late final Api _api;
  final UserAccount _userAccount;
  final NetConnectivityInfo _connectivityInfo;
  bool _isDisposed = false;

  RemoteRepository(this._userAccount, this._connectivityInfo) {
    this._api = Api(_userAccount);
  }

  Future<Result<List<SchemaVersion>>> schemaVersions() async {
    return _api.schemaVersions();
  }

  Future<Result<List<RemoteSchemaChangelog>>> changes(List<SchemaVersion> versions, {bool? includeDeleted}) async{
    return await _api.changes(versions, includeDeleted: includeDeleted);
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
