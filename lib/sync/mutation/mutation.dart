import 'package:vgbnd/sync/mutation/local_mutation_handler.dart';
import 'package:vgbnd/sync/sync_object.dart';

import '../../constants/constants.dart';
import '../object_mutation.dart';
import '../repository/_local_repository.dart';
import '../repository/_remote_repository.dart';

class SyncObjectReplacement {
  final SyncObject object;
  final int prevId, newId;

  SyncObjectReplacement({required this.prevId, required this.newId, required this.object});
}

class MutationResult {
  bool? _isSuccessful;
  Map<String, String>? _errorsMessages;
  SyncStorageType sourceStorage;
  List<SyncObject>? created;
  List<SyncObject>? updated;
  List<SyncObject>? deleted;
  List<SyncObjectReplacement>? replacements;

  MutationResult(this.sourceStorage);

  bool get isSuccessful {
    return _isSuccessful ?? false;
  }

  setSuccessful(bool success) {
    _isSuccessful = success;
  }

  setFailure({Map<String, String>? errorsMessages}) {
    _isSuccessful = false;
    _errorsMessages = errorsMessages;
  }

  add(SyncObjectMutationType op, SyncObject? obj) {
    if (obj == null) {
      return;
    }
    switch (op) {
      case SyncObjectMutationType.Create:
        created = (created ?? [])..add(obj);
        break;
      case SyncObjectMutationType.Update:
        updated = (updated ?? [])..add(obj);
        break;
      case SyncObjectMutationType.Delete:
        deleted = (deleted ?? [])..add(obj);
        break;
      default:
        return;
    }
  }

  replace(int prevId, int newId, SyncObject replacement) {
    replacements = (replacements ?? [])
      ..add(SyncObjectReplacement(prevId: prevId, newId: newId, object: replacement));
  }

  static MutationResult failure({SyncStorageType? sourceStorage, Map<String, String>? errorsMessages}) {
    return MutationResult(sourceStorage ?? SyncStorageType.Local).._errorsMessages = errorsMessages;
  }

  Map<String, dynamic> toJson() {
    return {};
  }

  Set<String> affectedSchemas() {
    if (this.isSuccessful) {
      final schemas = Set<String>();
      schemas.addAll((created ?? List.empty()).map((e) => e.getSchema().schemaName));
      schemas.addAll((updated ?? List.empty()).map((e) => e.getSchema().schemaName));
      schemas.addAll((deleted ?? List.empty()).map((e) => e.getSchema().schemaName));
      schemas.addAll((replacements ?? List.empty()).map((e) => e.object.getSchema().schemaName));

      return schemas;
    }

    return Set.identity();
  }
}

abstract class LocalMutationHandler<T> {
  static LocalMutationHandler<T> empty<T>() {
    return _EmptyMutationHandler();
  }

  static LocalMutationHandler<T> basic<T extends SyncObject<T>>({List<SyncObjectMutationType>? supportedTypes}) {
    return DefaultLocalMutationHandler<T>(supportedTypes ??
        [SyncObjectMutationType.Create, SyncObjectMutationType.Update, SyncObjectMutationType.Delete]);
  }

  // override in case not SyncObjectMutationType operations are supported
  bool canHandleMutationType(SyncObjectMutationType t) {
    switch (t) {
      case SyncObjectMutationType.Create:
      case SyncObjectMutationType.Update:
      case SyncObjectMutationType.Delete:
        return true;
      default:
        return false;
    }
  }

  Future<ObjectMutationData?> createMutation(LocalRepository localRepo, T instance, SyncObjectMutationType op);

  // writes the changelog in the local repository
  // this means that all local tables should be updated accordingly
  // normally, this will happen when the app is in offline mode
  Future<MutationResult> applyLocalMutation(ObjectMutationData mutationData, LocalRepository localRepo);
}

abstract class RemoteMutationHandler<T> {
  // override in case not SyncObjectMutationType operations are supported

  static RemoteMutationHandler<T> empty<T>() {
    return _EmptyMutationHandler();
  }

  // override in case not SyncObjectMutationType operations are supported
  bool canHandleMutationType(SyncObjectMutationType t) {
    switch (t) {
      case SyncObjectMutationType.Create:
      case SyncObjectMutationType.Update:
      case SyncObjectMutationType.Delete:
        return true;
      default:
        return false;
    }
  }

  // submit this changelog to the server
  Future<MutationResult> submitMutation(
      ObjectMutationData changelog, LocalRepository localRepo, RemoteRepository remoteRepo);

  // once the submission is successful, apply the results to the local repo
  Future<MutationResult> applyRemoteMutationResult(
      ObjectMutationData mutationData, MutationResult remoteResult, LocalRepository localRepo);
}

class _EmptyMutationHandler<T> with LocalMutationHandler<T>, RemoteMutationHandler<T> {
  @override
  bool canHandleMutationType(SyncObjectMutationType t) {
    return false;
  }

  @override
  Future<MutationResult> applyLocalMutation(ObjectMutationData mutationData, LocalRepository localRepo) {
    throw UnimplementedError();
  }

  @override
  Future<MutationResult> applyRemoteMutationResult(
      ObjectMutationData mutationData, MutationResult remoteResult, LocalRepository localRepo) {
    throw UnimplementedError();
  }

  @override
  Future<MutationResult> submitMutation(
      ObjectMutationData changelog, LocalRepository localRepo, RemoteRepository remoteRepo) {
    throw UnimplementedError();
  }

  @override
  Future<ObjectMutationData?> createMutation(LocalRepository localRepo, T instance, SyncObjectMutationType op) {
    // TODO: implement createMutation
    throw UnimplementedError();
  }
}

class RemoteMutationException implements Exception {
  bool isFatal() {
    // means that we cannot resubmit this mutation
    return false;
  }

  MutationResult asMutationResult() {
    return MutationResult.failure(sourceStorage: SyncStorageType.Remote);
  }
}
