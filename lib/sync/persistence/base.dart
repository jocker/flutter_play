import '../_local_repository.dart';
import '../_remote_repository.dart';
import '../record_changelog.dart';

class RemoteObjectInfo {
  final int id;
  final String schemaName;

  RemoteObjectInfo({required this.schemaName, required this.id});
}

class RemoteCreatedObjectInfo {
  final int id;
  final String schemaName;
  final int oldId;

  RemoteCreatedObjectInfo({required this.schemaName, required this.id, required this.oldId});
}

class RemoteSubmitResult {
  bool success;
  Map<String, String>? errorsMessages;
  List<RemoteCreatedObjectInfo>? created;
  List<RemoteObjectInfo>? updated;
  List<RemoteObjectInfo>? deleted;

  RemoteSubmitResult({required this.success, this.created, this.updated, this.deleted, this.errorsMessages});
}

abstract class LocalPersistence<T> {


  Future<RecordChangelog?> createChangelog(LocalRepository localRepo, T instance);

  // writes the changelog in the local repository
  // this means that all local tables should be updated accordingly
  // normally, this will happen when the app is in offline mode
  Future<bool> applyLocalChangelog(RecordChangelog changelog, LocalRepository localRepo);
}

abstract class RemotePersistence<T> {
  // submit this changelog to the server
  Future<RemoteSubmitResult> submitChangelog(
      RecordChangelog changelog, LocalRepository localRepo, RemoteRepository remoteRepo);

  Future<bool> applyRemoteChangelogResult(
      RecordChangelog localChangelog, RemoteSubmitResult remoteResult, LocalRepository localRepo);
}
