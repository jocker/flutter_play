enum SyncSchemaOp { RemoteRead, RemoteWrite }
enum SyncObjectMutationType { None, Create, Update, Delete }
enum SyncObjectPersistenceState {
  Unknown,
  LocalOnly /*object only exists in the local db*/,
  RemoteAndLocal /* object exists both locally and remotely */
}

enum SyncStorageType { Local, Remote }
