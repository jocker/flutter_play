
import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/sync/repository/local_repository.dart';
import 'package:vgbnd/sync/repository/remote_repository.dart';

import '../object_mutation.dart';
import '../sync_object.dart';
import 'default_local_mutation_handler.dart';
import 'mutation.dart';

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
  Future<MutationResult> applyLocalMutation(ObjectMutationData changelog, LocalRepository localRepo);
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
  Future<Result<List<RemoteSchemaChangelog>>> submitMutation(
      ObjectMutationData mutData, LocalRepository localRepo, RemoteRepository remoteRepo);

  // once the submission is successful, apply the results to the local repo
  Future<MutationResult> applyRemoteMutationResult(
      ObjectMutationData mutData, List<RemoteSchemaChangelog> remoteChangelog, LocalRepository localRepo);
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
  Future<ObjectMutationData?> createMutation(LocalRepository localRepo, T instance, SyncObjectMutationType op) {
    // TODO: implement createMutation
    throw UnimplementedError();
  }

  @override
  Future<MutationResult> applyRemoteMutationResult(ObjectMutationData mutData, List<RemoteSchemaChangelog> remoteChangelog, LocalRepository localRepo) {
    // TODO: implement applyRemoteMutationResult
    throw UnimplementedError();
  }

  @override
  Future<Result<List<RemoteSchemaChangelog>>> submitMutation(ObjectMutationData mutData, LocalRepository localRepo, RemoteRepository remoteRepo) {
    // TODO: implement submitMutation
    throw UnimplementedError();
  }
}
