import 'package:vgbnd/ext.dart';
import 'package:vgbnd/sync/sync_object.dart';

import '../../constants/constants.dart';

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

  String primaryErrorMessage(String defaultMessage) {
    return this.errorMessages().firstWhereOrNull((e) => true) ?? defaultMessage;
  }

  List<String> errorMessages() {
    if (_errorsMessages != null) {
      return List.of(_errorsMessages!.values);
    }
    return [];
  }

  void setSuccessful(bool success) {
    _isSuccessful = success;
  }

  setFailure({Map<String, String>? errorsMessages}) {
    _isSuccessful = false;
    _errorsMessages = errorsMessages;
  }

  addForCreate(SyncObject? obj) {
    add(SyncObjectMutationType.Create, obj);
  }

  addForDelete(SyncObject? obj) {
    add(SyncObjectMutationType.Delete, obj);
  }

  addForUpdate(SyncObject? obj) {
    add(SyncObjectMutationType.Update, obj);
  }

  add(SyncObjectMutationType op, SyncObject? obj) {
    if (obj == null) {
      return;
    }
    switch (op) {
      case SyncObjectMutationType.Create:
        created = (created ?? [])
          ..add(obj);
        break;
      case SyncObjectMutationType.Update:
        updated = (updated ?? [])
          ..add(obj);
        break;
      case SyncObjectMutationType.Delete:
        deleted = (deleted ?? [])
          ..add(obj);
        break;
      default:
        return;
    }
  }

  replace(int prevId, int newId, SyncObject replacement) {
    replacements = (replacements ?? [])
      ..add(SyncObjectReplacement(prevId: prevId, newId: newId, object: replacement));
  }

  static MutationResult remoteFailure({String? message, Map<String, String>? messages}) {
    return failure(
        sourceStorage: SyncStorageType.Remote,
        errorsMessages: mergeErrorMessages(message: message, messages: messages));
  }

  static MutationResult localFailure({String? message, Map<String, String>? messages}) {
    return failure(
        sourceStorage: SyncStorageType.Local,
        errorsMessages: mergeErrorMessages(message: message, messages: messages));
  }

  static MutationResult failure({SyncStorageType? sourceStorage, Map<String, String>? errorsMessages}) {
    return MutationResult(sourceStorage ?? SyncStorageType.Local)
      .._errorsMessages = errorsMessages;
  }

  static Map<String, String>? mergeErrorMessages({String? message, Map<String, String>? messages}) {
    if (messages != null) {
      return messages;
    } else if (message != null) {
      return {"base": message};
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {};
  }

  Set<String> affectedSchemas() {
    if (this.isSuccessful) {
      final schemas = Set<String>();
      schemas.addAll((created ?? List.empty()).map((e) =>
      e
          .getSchema()
          .schemaName));
      schemas.addAll((updated ?? List.empty()).map((e) =>
      e
          .getSchema()
          .schemaName));
      schemas.addAll((deleted ?? List.empty()).map((e) =>
      e
          .getSchema()
          .schemaName));
      schemas.addAll((replacements ?? List.empty()).map((e) =>
      e.object
          .getSchema()
          .schemaName));

      return schemas;
    }

    return Set.identity();
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
